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
        setState(() { _loading = false; });
        return;
      }

      final clubSnap = await FirebaseDatabase.instance
          .ref('Person/$_sid/club')
          .get();

      final clubs = <String>[];
      if (clubSnap.exists) {
        final data = Map<dynamic, dynamic>.from(clubSnap.value as Map);
        for (final e in data.entries) {
          // value가 clubName이 되도록 가정 (네 DB 서비스가 그랬음)
          clubs.add(e.value.toString());
        }
      }

      setState(() {
        _clubs = clubs;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; });
    }
  }

  Stream<Map<String, dynamic>?> lastMessageStream(String club) {
    final ref = FirebaseDatabase.instance.ref('Club/$club/chat/lastMessage');
    return ref.onValue.map((event) {
      if (!event.snapshot.exists) return null;
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }

  String _previewText(Map<String, dynamic>? last) {
    if (last == null) return '메시지가 없습니다.';
    final t = (last['text'] ?? '').toString();
    return t.isEmpty ? '메시지가 없습니다.' : t;
    // createdAt으로 시간 뱃지 붙이고 싶으면 여기서 포맷팅 추가
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('채팅')),
        body: const Center(child: CircularProgressIndicator()),
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
                title: Text(club, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ClubChatPage(clubName: club)),
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
