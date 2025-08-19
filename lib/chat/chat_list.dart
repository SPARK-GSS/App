import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:gss/chat/club_chat.dart';
import 'package:gss/services/AuthService.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  bool _loading = true;
  String? _sid;
  final List<String> _clubs = [];

  // club -> lastMessage map
  final Map<String, Map<String, dynamic>?> _lastByClub = {};
  // listener 보관
  final List<StreamSubscription<DatabaseEvent>> _subs = [];

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _initLoad() async {
    try {
      _sid = await user_stuid();
      if (_sid == null) {
        setState(() => _loading = false);
        return;
      }

      final clubSnap = await FirebaseDatabase.instance.ref('Person/$_sid/club').get();
      if (clubSnap.exists) {
        final data = Map<dynamic, dynamic>.from(clubSnap.value as Map);
        for (final e in data.entries) {
          final club = e.value.toString();
          _clubs.add(club);
          _listenLastMessage(club);
        }
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _listenLastMessage(String club) {
    final ref = FirebaseDatabase.instance.ref('Club/$club/chat/lastMessage');
    final sub = ref.onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists) {
        _lastByClub[club] = Map<String, dynamic>.from(event.snapshot.value as Map);
      } else {
        _lastByClub[club] = null;
      }
      setState(() {});
    });
    _subs.add(sub);
  }

  int _lastCreatedAt(String club) {
    final last = _lastByClub[club];
    if (last == null) return 0;
    final v = last['createdAt'];
    return (v is int) ? v : 0;
  }

  String _previewText(String club) {
    final last = _lastByClub[club];
    if (last == null) return '메시지가 없습니다.';
    final t = (last['text'] ?? '').toString();
    return t.isEmpty ? '메시지가 없습니다.' : t;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('채팅')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 최신순 정렬
    final sortedClubs = [..._clubs]
      ..sort((a, b) => _lastCreatedAt(b).compareTo(_lastCreatedAt(a)));

    return Scaffold(
      appBar: AppBar(title: const Text('채팅')),
      body: sortedClubs.isEmpty
          ? const Center(child: Text('가입한 동아리의 채팅방이 없습니다.'))
          : ListView.separated(
        itemCount: sortedClubs.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final club = sortedClubs[i];
          final preview = _previewText(club);
          return ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundImage: AssetImage('assets/$club.png'),
              backgroundColor: Colors.grey[200],
            ),
            title: Text(
              club,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: (_sid == null)
                ? null
                : UnreadBadge(clubName: club, sid: _sid!),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ClubChatPage(clubName: club)),
              );
            },
          );
        },
      ),
    );
  }
}

/// ───────────────────────────────────────────────────────────
/// 미읽음 배지 (이전 답변의 UnreadBadge 그대로 사용)
/// ───────────────────────────────────────────────────────────
class UnreadBadge extends StatefulWidget {
  final String clubName;
  final String sid;
  const UnreadBadge({super.key, required this.clubName, required this.sid});

  @override
  State<UnreadBadge> createState() => _UnreadBadgeState();
}

class _UnreadBadgeState extends State<UnreadBadge> {
  final _controller = StreamController<int>.broadcast();

  StreamSubscription<DatabaseEvent>? _readSub;
  StreamSubscription<DatabaseEvent>? _msgsSub;

  @override
  void initState() {
    super.initState();
    _wire();
  }

  void _wire() {
    final readRef = FirebaseDatabase.instance
        .ref('Club/${widget.clubName}/chat/read/${widget.sid}/lastReadAt');

    _readSub = readRef.onValue.listen((readEvt) {
      final lastReadAt =
      (readEvt.snapshot.value ?? 0) is int ? readEvt.snapshot.value as int : 0;

      _msgsSub?.cancel();
      final msgsQuery = FirebaseDatabase.instance
          .ref('Club/${widget.clubName}/chat/messages')
          .orderByChild('createdAt')
          .startAt(lastReadAt + 1);

      _msgsSub = msgsQuery.onValue.listen((evt) {
        if (!evt.snapshot.exists) {
          _controller.add(0);
          return;
        }
        if (evt.snapshot.value is List) {
          final list = List.from(evt.snapshot.value as List);
          _controller.add(list.where((e) => e != null).length);
        } else {
          final map = Map<dynamic, dynamic>.from(evt.snapshot.value as Map);
          _controller.add(map.length);
        }
      });
    });
  }

  @override
  void dispose() {
    _readSub?.cancel();
    _msgsSub?.cancel();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _controller.stream,
      builder: (_, snap) {
        final count = snap.data ?? 0;
        if (count <= 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}
