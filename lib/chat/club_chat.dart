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

  // 로컬 메시지 목록 (스트림으로 채우기)
  final List<Map<String, dynamic>> _messages = [];
  late Stream<DatabaseEvent> _childAddedSub;

  @override
  void initState() {
    super.initState();
    _messagesRef = FirebaseDatabase.instance.ref('Club/${widget.clubName}/chat/messages');
    _initUserThenListen();
  }

  Future<void> _initUserThenListen() async {
    _sid = await user_stuid();
    _name = await user_name();

    // 기존 메시지 먼저 로드(선택) + 새로 추가되는 메시지 listen
    // 여기서는 간단히 childAdded만 사용 (전체 메시지를 순차 수신)
    _childAddedSub = _messagesRef.orderByChild('createdAt').onChildAdded;
    _childAddedSub.listen((event) {
      if (!event.snapshot.exists) return;
      final m = Map<String, dynamic>.from(event.snapshot.value as Map);
      _messages.add(m);
      if (mounted) {
        setState(() {});
        _jumpToBottom();
      }
    });
  }

  void _jumpToBottom() {
    // 프레임 끝나고 스크롤 (부드럽게)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_sid == null || _name == null) return;

    final msg = {
      'senderSid': _sid,
      'senderName': _name,
      'text': text,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

    final newRef = _messagesRef.push();
    await newRef.set(msg);

    // lastMessage 업데이트
    final lastRef = FirebaseDatabase.instance.ref('Club/${widget.clubName}/chat/lastMessage');
    await lastRef.set({'text': text, 'createdAt': msg['createdAt']});

    _controller.clear();
    _jumpToBottom();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool _isMine(Map<String, dynamic> m) => (m['senderSid']?.toString() ?? '') == (_sid ?? '');

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
                final name = (m['senderName'] ?? '').toString();
                final text = (m['text'] ?? '').toString();

                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.74,
                    ),
                    decoration: BoxDecoration(
                      color: mine ? Colors.purple.shade100 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (!mine)
                          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(text, style: const TextStyle(fontSize: 15)),
                      ],
                    ),
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
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
