import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:gss/services/AuthService.dart';

class ClubChatPage extends StatefulWidget {
  final String clubName;
  const ClubChatPage({super.key, required this.clubName});

  @override
  State<ClubChatPage> createState() => _ClubChatPageState();
}

class _ClubChatPageState extends State<ClubChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  String? _sid;
  String? _name;

  late DatabaseReference _messagesRef;
  DatabaseReference? _readRef;

  final List<Map<String, dynamic>> _messages = [];
  late Stream<DatabaseEvent> _childAddedSub;

  // officer 캐시
  Map<String, dynamic> _officers = {};

  @override
  void initState() {
    super.initState();
    _messagesRef =
        FirebaseDatabase.instance.ref('Club/${widget.clubName}/chat/messages');
    _initUserThenListen();
  }

  Future<void> _initUserThenListen() async {
    _sid = await user_stuid();
    _name = await user_name();

    if (_sid != null) {
      _readRef = FirebaseDatabase.instance
          .ref('Club/${widget.clubName}/chat/read/$_sid');
      await _markReadNow();
    }

    await _loadOfficerOnce();

    _childAddedSub = _messagesRef.orderByChild('createdAt').onChildAdded;
    _childAddedSub.listen((event) async {
      if (!event.snapshot.exists) return;
      final m = Map<String, dynamic>.from(event.snapshot.value as Map);
      _messages.add(m);
      if (mounted) {
        setState(() {});
        _jumpToBottom();
      }
      await _markReadNow();
    });
  }

  Future<void> _loadOfficerOnce() async {
    final snap = await FirebaseDatabase.instance
        .ref('Club/${widget.clubName}/officer')
        .get();
    if (snap.exists) {
      _officers = Map<String, dynamic>.from(snap.value as Map);
    } else {
      _officers = {};
    }
  }

  String _roleOfSid(String? sid) {
    if (sid == null) return 'none';
    final pres = _officers['president']?.toString();
    if (pres == sid) return 'president';
    final vice = _officers['vice']?.toString();
    if (vice == sid) return 'vice';
    if (_officers['managers'] is Map) {
      final m = Map<dynamic, dynamic>.from(_officers['managers']);
      if (m.containsKey(sid) && m[sid] == true) return 'manager';
    }
    for (final e in _officers.entries) {
      final k = e.key.toString();
      if (k.startsWith('manager') && e.value?.toString() == sid) {
        return 'manager';
      }
    }
    return 'none';
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'president':
        return '회장';
      case 'vice':
        return '부회장';
      case 'manager':
        return '운영진';
      default:
        return '부원';
    }
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _markReadNow() async {
    if (_readRef == null) return;
    await _readRef!.update({
      'lastReadAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_sid == null || _name == null) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final msg = {
      'senderSid': _sid,
      'senderName': _name,
      'text': text,
      'createdAt': nowMs,
    };

    final newRef = _messagesRef.push();
    await newRef.set(msg);

    final lastRef = FirebaseDatabase.instance
        .ref('Club/${widget.clubName}/chat/lastMessage');
    await lastRef.set({'text': text, 'createdAt': nowMs});

    _controller.clear();
    _jumpToBottom();
    await _markReadNow();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool _isMine(Map<String, dynamic> m) =>
      (m['senderSid']?.toString() ?? '') == (_sid ?? '');

  // ───────── 날짜/시간 포맷 유틸 ─────────
  static const _weekdayKr = {
    1: '월요일',
    2: '화요일',
    3: '수요일',
    4: '목요일',
    5: '금요일',
    6: '토요일',
    7: '일요일',
  };

  String _formatDateHeader(DateTime d) {
    return '${d.year}년 ${d.month}월 ${d.day}일 ${_weekdayKr[d.weekday] ?? ''}';
    // 필요하면 locale 패키지로 더 정교하게 포맷팅 가능
  }

  String _formatTime(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  DateTime _ymd(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.clubName} 채팅')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final mine = _isMine(m);
                final senderSid = (m['senderSid'] ?? '').toString();
                final name = (m['senderName'] ?? '').toString();
                final text = (m['text'] ?? '').toString();
                final createdAt = DateTime.fromMillisecondsSinceEpoch(
                  (m['createdAt'] ?? 0) as int,
                );

                // 날짜 구분선 표시 여부 판단
                bool showDateDivider = false;
                final currentYmd = _ymd(createdAt);
                if (i == 0) {
                  showDateDivider = true;
                } else {
                  final prev = _messages[i - 1];
                  final prevAt = DateTime.fromMillisecondsSinceEpoch(
                      (prev['createdAt'] ?? 0) as int);
                  if (_ymd(prevAt) != currentYmd) showDateDivider = true;
                }

                final role = _roleOfSid(senderSid);
                final nameWithRole = '$name(${_roleLabel(role)})';
                final timeText = _formatTime(createdAt);

                // 이름(역할) — 말풍선 밖 / 메시지 — 말풍선 안
                // 시간 — 말풍선 옆 (내 메시지는 왼쪽, 상대 메시지는 오른쪽)
                final messageRow = Row(
                  mainAxisAlignment:
                  mine ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: mine
                      ? <Widget>[
                    // 내 메시지: 시간 먼저, 그다음 버블
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(text, style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  ]
                      : <Widget>[
                    // 상대 메시지: 버블 먼저, 그다음 시간
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(text, style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                );

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment:
                    mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (showDateDivider)
                        _DateDivider(label: _formatDateHeader(currentYmd)),
                      const SizedBox(height: 4),
                      // 이름(역할) — 말풍선 밖
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          mine
                              ? '$_name(${_roleLabel(_roleOfSid(_sid))})'
                              : nameWithRole,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: mine ? Colors.black54 : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // 메시지 + 시간
                      messageRow,
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: '메시지를 입력하세요',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 날짜 구분선 위젯
class _DateDivider extends StatelessWidget {
  final String label;
  const _DateDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(height: 24)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider(height: 24)),
      ],
    );
  }
}
