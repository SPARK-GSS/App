import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class Notice {
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final int createdAt;
  final String? author;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    this.author,
  });

  factory Notice.fromMap(String id, Map m) {
    return Notice(
      id: id,
      title: (m['title'] ?? '').toString(),
      content: (m['content'] ?? '').toString(),
      imageUrl: (m['imageUrl'] as String?),
      createdAt: (m['createdAt'] ?? 0) as int,
      author: m['author'] as String?,
    );
  }
}

class NoticeBoard extends StatelessWidget {
  final String clubName;
  const NoticeBoard({super.key, required this.clubName});

  DatabaseReference get _ref =>
      FirebaseDatabase.instance.ref('Club/$clubName/notices');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DatabaseEvent>(
        stream: _ref.onValue,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data?.snapshot.value;
          if (data == null) {
            return const Center(child: Text('등록된 공지가 없습니다.'));
          }
          final map = Map<String, dynamic>.from(data as Map);
          // 최신순 정렬 (createdAt 내림차순)
          final items = map.entries
              .map((e) => Notice.fromMap(e.key, Map<String, dynamic>.from(e.value)))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final n = items[i];
              return ListTile(
                leading: n.imageUrl != null && n.imageUrl!.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(n.imageUrl!, width: 56, height: 56, fit: BoxFit.cover),
                )
                    : Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.image_not_supported),
                ),
                title: Text(
                  n.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  n.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => NoticeDetailPage(notice: n, clubName: clubName),
                  ));
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => NoticeEditorPage(clubName: clubName),
          ));
        },
        icon: const Icon(Icons.add),
        label: const Text('공지 작성'),
      ),
    );
  }
}

class NoticeDetailPage extends StatelessWidget {
  final Notice notice;
  final String clubName;
  const NoticeDetailPage({super.key, required this.notice, required this.clubName});

  @override
  Widget build(BuildContext context) {
    final created = DateTime.fromMillisecondsSinceEpoch(notice.createdAt);
    return Scaffold(
      appBar: AppBar(title: Text(notice.title, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (notice.imageUrl != null && notice.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(notice.imageUrl!, fit: BoxFit.cover),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (notice.author != null)
                Text(notice.author!, style: const TextStyle(color: Colors.grey)),
              const Spacer(),
              Text(
                '${created.year}.${created.month.toString().padLeft(2, '0')}.${created.day.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            notice.content,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class NoticeEditorPage extends StatefulWidget {
  final String clubName;
  const NoticeEditorPage({super.key, required this.clubName});

  @override
  State<NoticeEditorPage> createState() => _NoticeEditorPageState();
}

class _NoticeEditorPageState extends State<NoticeEditorPage> {
  final _titleC = TextEditingController();
  final _contentC = TextEditingController();
  final _imageUrlC = TextEditingController();
  bool _saving = false;

  DatabaseReference get _ref =>
      FirebaseDatabase.instance.ref('Club/${widget.clubName}/notices');

  Future<void> _save() async {
    final title = _titleC.text.trim();
    final content = _contentC.text.trim();
    final imageUrl = _imageUrlC.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 내용을 입력해 주세요.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final author = user?.email;

      final newRef = _ref.push();
      await newRef.set({
        'title': title,
        'content': content,
        'imageUrl': imageUrl,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'author': author,
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공지가 등록되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _titleC.dispose();
    _contentC.dispose();
    _imageUrlC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('공지 작성')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleC,
            decoration: const InputDecoration(
              labelText: '제목',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _imageUrlC,
            decoration: const InputDecoration(
              labelText: '이미지 URL(선택)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentC,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: '내용',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _saving
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('등록'),
          ),
        ],
      ),
    );
  }
}
