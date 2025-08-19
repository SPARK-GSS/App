import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:gss/chat/club_chat.dart';
import 'package:gss/services/AuthService.dart';
import 'dart:async';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  bool _loading = true;
  String? _sid;
  List<String> _clubs = [];

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    try {
      _sid = await user_stuid();
      if (_sid == null) {
        setState(() => _loading = false);
        return;
      }

      final clubSnap =
      await FirebaseDatabase.instance.ref('Person/$_sid/club').get();

      final clubs = <String>[];
      if (clubSnap.exists) {
        final data = Map<dynamic, dynamic>.from(clubSnap.value as Map);
        for (final e in data.entries) {
          clubs.add(e.value.toString()); // value를 clubName으로 사용하는 구조
        }
      }

      setState(() {
        _clubs = clubs;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Stream<Map<String, dynamic>?> lastMessageStream(String club) {
    final ref =
    FirebaseDatabase.instance.ref('Club/$club/chat/lastMessage');
    return ref.onValue.map((event) {
      if (!event.snapshot.exists) return null;
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }

  String _previewText(Map<String, dynamic>? last) {
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

    return Scaffold(
      appBar: AppBar(title: const Text('채팅')),
      body: _clubs.isEmpty
          ? const Center(child: Text('가입한 동아리의 채팅방이 없습니다.'))
          : ListView.separated(
        itemCount: _clubs.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final club = _clubs[i];
          return StreamBuilder<Map<String, dynamic>?>(
            stream: lastMessageStream(club),
            builder: (ctx, snap) {
              final preview = _previewText(snap.data);
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
                    MaterialPageRoute(
                      builder: (_) => ClubChatPage(clubName: club),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// ───────────────────────────────────────────────────────────
/// 미읽음 배지: Club/{club}/chat/read/{sid}.lastReadAt 기준으로 집계
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

      // messages 중 lastReadAt보다 큰 것 카운트
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
          // 희소 배열일 수 있어 length 신뢰 어려움 → Map으로 변환 시도
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
