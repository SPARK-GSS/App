import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:gss/services/AuthService.dart';
import 'package:image_picker/image_picker.dart';

/// =======================
/// 모델
/// =======================
class Notice {
  final String id;
  final String title;
  final String content;
  final List<String> imageUrls;
  final int createdAt;
  final String? author;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.imageUrls,
    required this.createdAt,
    this.author,
  });

  factory Notice.fromMap(String id, Map m) {
    // 하위호환: imageUrl (String) OR imageUrls (List/Map)
    final List<String> imgs = [];
    if (m['imageUrls'] is List) {
      imgs.addAll(List.from(m['imageUrls']).whereType<String>());
    } else if (m['imageUrls'] is Map) {
      imgs.addAll(Map<String, dynamic>.from(m['imageUrls']).values
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty));
    } else if (m['imageUrl'] is String) {
      final s = (m['imageUrl'] as String);
      if (s.isNotEmpty) imgs.add(s);
    }

    return Notice(
      id: id,
      title: (m['title'] ?? '').toString(),
      content: (m['content'] ?? '').toString(),
      imageUrls: imgs,
      createdAt: (m['createdAt'] ?? 0) as int,
      author: m['author'] as String?,
    );
  }
}

/// =======================
/// 공지 리스트
/// =======================
class NoticeBoard extends StatelessWidget {
  final String clubName;
  const NoticeBoard({super.key, required this.clubName});

  DatabaseReference get _ref =>
      FirebaseDatabase.instance.ref('Club/$clubName/notices');

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: OfficerService.canManage(clubName),
      builder: (context, snap) {
        final canManage = snap.data ?? false;
        return Scaffold(
          backgroundColor: Colors.white,
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
              final items = map.entries
                  .map((e) => Notice.fromMap(
                e.key,
                Map<String, dynamic>.from(e.value),
              ))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final n = items[i];
                  final thumb = (n.imageUrls.isNotEmpty) ? n.imageUrls.first : null;
                  return ListTile(
                    leading: thumb != null
                        ? Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            thumb,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (n.imageUrls.length > 1)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '+${n.imageUrls.length - 1}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11),
                              ),
                            ),
                          ),
                      ],
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
                        builder: (_) =>
                            NoticeDetailPage(notice: n, clubName: clubName),
                      ));
                    },
                  );
                },
              );
            },
          ),
          floatingActionButton: canManage
              ? FloatingActionButton.extended(
            backgroundColor: Color.fromRGBO(216, 162, 163, 1.0),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => NoticeEditorPage(clubName: clubName),
              ));
            },
            icon: const Icon(Icons.add, color: Colors.white,),
            label: const Text('공지 작성', style: TextStyle(color: Colors.white),),
          )
              : null,
        );
      },
    );
  }
}

/// =======================
/// 공지 상세 + 케밥 메뉴(수정/삭제)
/// =======================
class NoticeDetailPage extends StatefulWidget {
  final Notice notice;
  final String clubName;
  const NoticeDetailPage(
      {super.key, required this.notice, required this.clubName});

  @override
  State<NoticeDetailPage> createState() => _NoticeDetailPageState();
}

class _NoticeDetailPageState extends State<NoticeDetailPage> {
  late Notice _notice;
  bool _menuVisible = false;

  DatabaseReference get _ref =>
      FirebaseDatabase.instance.ref('Club/${widget.clubName}/notices');

  @override
  void initState() {
    super.initState();
    _notice = widget.notice;
    _computeMenuVisible();
  }

  Future<void> _computeMenuVisible() async {
    final canManage = await OfficerService.canManage(widget.clubName);
    if (mounted) setState(() => _menuVisible = canManage || false);
  }

  Future<void> _deleteNotice() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제하시겠습니까?'),
        content: const Text('삭제 후 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;

    try {
      // 1) DB 삭제
      await _ref.child(_notice.id).remove();
      // 2) Storage 이미지들도 정리(선택)
      await _deleteAllImagesFromStorage(_notice);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('삭제되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  Future<void> _deleteAllImagesFromStorage(Notice n) async {
    if (n.imageUrls.isEmpty) return;
    // 이미지 파일 경로를 정확히 모르므로, notice 폴더 통째로 지우는 방식을 권장
    // 구조: Club/{club}/notices/{id}/images/{...}
    final folderRef = FirebaseStorage.instance
        .ref()
        .child('Club/${widget.clubName}/notices/${n.id}/images');
    try {
      final list = await folderRef.listAll();
      for (final item in list.items) {
        await item.delete();
      }
    } catch (_) {
      // 폴더가 없거나 권한 문제일 경우 무시
    }
  }

  Future<void> _editNotice() async {
    final updated = await Navigator.of(context).push<Notice>(
      MaterialPageRoute(
        builder: (_) => NoticeEditorPage(
          clubName: widget.clubName,
          initial: _notice,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _notice = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = DateTime.fromMillisecondsSinceEpoch(_notice.createdAt);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(_notice.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (_menuVisible)
            PopupMenuButton<String>(
              color: Colors.white,
              onSelected: (v) {
                if (v == 'edit') _editNotice();
                if (v == 'delete') _deleteNotice();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('수정')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('삭제', style: TextStyle(color: Color.fromRGBO(
                      209, 87, 90, 1.0))),
                ),
              ],
              icon: const Icon(Icons.more_vert),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          const SizedBox(height: 16),
          if (_notice.imageUrls.isNotEmpty)
            _ImagesGallery(imageUrls: _notice.imageUrls),
          const SizedBox(height: 16),

          Text(
            _notice.content,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// 슬라이더 + 썸네일 그리드(간단 버전: 가로 스크롤 썸네일)
class _ImagesGallery extends StatefulWidget {
  final List<String> imageUrls;
  const _ImagesGallery({required this.imageUrls});

  @override
  State<_ImagesGallery> createState() => _ImagesGalleryState();
}

class _ImagesGalleryState extends State<_ImagesGallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: PageView.builder(
            itemCount: urls.length,
            controller: PageController(viewportFraction: 1),
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    insetPadding: const EdgeInsets.all(12),
                    child: InteractiveViewer(
                      child: Image.network(urls[i], fit: BoxFit.contain),
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(urls[i], fit: BoxFit.cover),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => setState(() => _index = i),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: i == _index ? Color.fromRGBO(216, 162, 163, 1.0) : Colors.transparent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(urls[i],
                      width: 100, height: 60, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// =======================
/// 공지 작성/수정 (멀티 이미지 업로드)
/// =======================
class NoticeEditorPage extends StatefulWidget {
  final String clubName;
  final Notice? initial; // null = 생성, not null = 수정
  const NoticeEditorPage({super.key, required this.clubName, this.initial});

  bool get isEdit => initial != null;

  @override
  State<NoticeEditorPage> createState() => _NoticeEditorPageState();
}

class _NoticeEditorPageState extends State<NoticeEditorPage> {
  final _titleC = TextEditingController();
  final _contentC = TextEditingController();

  // 기존에 저장되어 있던 원격 이미지 URL
  final List<String> _existingUrls = [];
  // 이번에 새로 추가해서 업로드할 로컬 이미지들
  final List<XFile> _localImages = [];

  bool _saving = false;

  DatabaseReference get _ref =>
      FirebaseDatabase.instance.ref('Club/${widget.clubName}/notices');

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      _titleC.text = widget.initial!.title;
      _contentC.text = widget.initial!.content;
      _existingUrls.addAll(widget.initial!.imageUrls);
    }
  }

  @override
  void dispose() {
    _titleC.dispose();
    _contentC.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() => _localImages.addAll(picked));
  }

  Future<void> _removeExistingAt(int index) async {
    setState(() => _existingUrls.removeAt(index));
  }

  Future<void> _removeLocalAt(int index) async {
    setState(() => _localImages.removeAt(index));
  }

  Future<List<String>> _uploadLocalImages(String noticeId) async {
    final storage = FirebaseStorage.instance;
    final urls = <String>[];
    for (final x in _localImages) {
      final file = File(x.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${x.name}';
      final ref = storage
          .ref()
          .child('Club/${widget.clubName}/notices/$noticeId/images/$fileName');
      final task = ref.putFile(file);
      await task;
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  Future<void> _save() async {
    final title = _titleC.text.trim();
    final content = _contentC.text.trim();
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
        // 수정: 기존 noticeId 사용
        final id = widget.initial!.id;
        final newUrls = await _uploadLocalImages(id);
        final merged = [..._existingUrls, ...newUrls];

        await _ref.child(id).update({
          'title': title,
          'content': content,
          'imageUrls': merged,
        });

        if (!mounted) return;
        Navigator.of(context).pop(Notice(
          id: id,
          title: title,
          content: content,
          imageUrls: merged,
          createdAt: widget.initial!.createdAt,
          author: widget.initial!.author,
        ));
      } else {
        // 생성: id 먼저 확보 → 이미지 업로드 → 최종 set
        final newRef = _ref.push();
        final id = newRef.key!;
        final uploaded = await _uploadLocalImages(id);

        await newRef.set({
          'title': title,
          'content': content,
          'imageUrls': uploaded,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'author': author,
        });

        if (!mounted) return;
        Navigator.of(context).pop(); // 목록은 스트림으로 갱신됨
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

  Widget _buildImagesEditor() {
    return Center(
        child:Column(
      //crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        //const Text('이미지(여러 장 가능)'),
        //const SizedBox(height: 8),

        // 기존 이미지들(원격 URL)
        if (_existingUrls.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_existingUrls.length, (i) {
              final url = _existingUrls[i];
              return Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(url, width: 96, height: 96, fit: BoxFit.cover),
                  ),
                  IconButton(
                    icon: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54, borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                    onPressed: () => _removeExistingAt(i),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 12),
        ],

        // 새로 추가한 로컬 이미지들
        if (_localImages.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_localImages.length, (i) {
              final x = _localImages[i];
              return Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(x.path),
                        width: 96, height: 96, fit: BoxFit.cover),
                  ),
                  IconButton(
                    icon: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54, borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                    onPressed: () => _removeLocalAt(i),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 12),
        ],

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.photo_library, color: Colors.black,),
              label: const Text('이미지 선택', style: TextStyle(color: Colors.black),),
            ),
            const SizedBox(width: 8),
            if (_saving) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      ],
    ),);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(widget.isEdit ? '공지 수정' : '공지 작성'), backgroundColor: Colors.white,),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleC,
            decoration:
            const InputDecoration(
              labelText: '제목',
              border: OutlineInputBorder(),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                borderSide: BorderSide(color: Colors.grey, width: 1),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                borderSide: BorderSide(
                  color: Color.fromRGBO(119, 119, 119, 1.0),
                  width: 2,
                ),
              ),
              floatingLabelStyle: const TextStyle(
                color: Color.fromRGBO(119, 119, 119, 1.0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _contentC,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: '내용',
              border: OutlineInputBorder(),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                borderSide: BorderSide(color: Colors.grey, width: 1),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                borderSide: BorderSide(
                  color: Color.fromRGBO(119, 119, 119, 1.0),
                  width: 2,
                ),
              ),
              floatingLabelStyle: const TextStyle(
                color: Color.fromRGBO(119, 119, 119, 1.0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),

          _buildImagesEditor(),
          const SizedBox(height: 20),

      _saving
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints.tightFor(width: 100, height: 40),
          child: ElevatedButton(
            onPressed: _save,
            //icon: const Icon(Icons.save),
            child: Text(widget.isEdit ? '수정' : '등록'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(100, 40),
              backgroundColor: Color.fromRGBO(216, 162, 163, 1.0),
              foregroundColor: Color.fromRGBO(255, 255, 255, 1.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 5,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
      ],
      ),
    );
  }
}

