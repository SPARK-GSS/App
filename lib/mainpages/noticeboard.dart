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

class NoticeDetailPage extends StatefulWidget {
  final Notice notice;
  final String clubName;
  const NoticeDetailPage({super.key, required this.notice, required this.clubName});

  @override
  State<NoticeDetailPage> createState() => _NoticeDetailPageState();
}

class _NoticeDetailPageState extends State<NoticeDetailPage> {
  late Notice _notice; // 수정 후 갱신용
  DatabaseReference get _ref =>
      FirebaseDatabase.instance.ref('Club/${widget.clubName}/notices');

  @override
  void initState() {
    super.initState();
    _notice = widget.notice;
  }

  Future<void> _deleteNotice() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제하시겠습니까?'),
        content: const Text('삭제 후 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _ref.child(_notice.id).remove();
      if (!mounted) return;
      Navigator.of(context).pop(); // 상세 페이지 닫기
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  Future<void> _editNotice() async {
    final updated = await Navigator.of(context).push<Notice>(
      MaterialPageRoute(
        builder: (_) => NoticeEditorPage(
          clubName: widget.clubName,
          initial: _notice, // 수정 모드
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _notice = updated); // 화면 즉시 갱신
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = DateTime.fromMillisecondsSinceEpoch(_notice.createdAt);
    final currentEmail = FirebaseAuth.instance.currentUser?.email;
    final isAuthor = (_notice.author != null && _notice.author == currentEmail);

    return Scaffold(
      appBar: AppBar(
        title: Text(_notice.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (isAuthor)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _editNotice();
                if (v == 'delete') _deleteNotice();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('수정')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('삭제', style: TextStyle(color: Colors.red)),
                ),
              ],
              icon: const Icon(Icons.more_vert), // 케밥 메뉴
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_notice.imageUrl != null && _notice.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(_notice.imageUrl!, fit: BoxFit.cover),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_notice.author != null)
                Text(_notice.author!, style: const TextStyle(color: Colors.grey)),
              const Spacer(),
              Text(
                '${created.year}.${created.month.toString().padLeft(2, '0')}.${created.day.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _notice.content,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class NoticeEditorPage extends StatefulWidget {
  final String clubName;
  final Notice? initial; // null이면 생성, 있으면 수정
  const NoticeEditorPage({super.key, required this.clubName, this.initial});

  bool get isEdit => initial != null;

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

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      _titleC.text = widget.initial!.title;
      _contentC.text = widget.initial!.content;
      _imageUrlC.text = widget.initial!.imageUrl ?? '';
    }
  }

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

      if (widget.isEdit) {
        // ✅ 수정
        final id = widget.initial!.id;
        final updated = {
          'title': title,
          'content': content,
          'imageUrl': imageUrl,
        };
        await _ref.child(id).update(updated);

        // 수정된 Notice를 되돌려주어 상세페이지가 즉시 갱신되도록
        final edited = Notice(
          id: id,
          title: title,
          content: content,
          imageUrl: imageUrl.isEmpty ? null : imageUrl,
          createdAt: widget.initial!.createdAt,
          author: widget.initial!.author,
        );
        if (!mounted) return;
        Navigator.of(context).pop(edited);
      } else {
        // ✅ 신규 작성
        final newRef = _ref.push();
        await newRef.set({
          'title': title,
          'content': content,
          'imageUrl': imageUrl,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'author': author,
        });
        if (!mounted) return;
        Navigator.of(context).pop(); // 새 글은 목록 스트림으로 자동 반영됨
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isEdit ? '수정되었습니다.' : '등록되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
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
      appBar: AppBar(title: Text(widget.isEdit ? '공지 수정' : '공지 작성')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleC,
            decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _imageUrlC,
            decoration: const InputDecoration(labelText: '이미지 URL(선택)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentC,
            maxLines: 10,
            decoration: const InputDecoration(labelText: '내용', alignLabelWithHint: true, border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          _saving
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(widget.isEdit ? '수정' : '등록'),
          ),
        ],
      ),
    );
  }
}
