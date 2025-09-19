// lib/mainpages/event.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

enum PostType { meetup, free }

extension PostTypeX on PostType {
  String get label => this == PostType.meetup ? '번개모임' : '잡담';
  String get key   => this == PostType.meetup ? 'meetup'   : 'free';
}

PostType postTypeFromKey(String k) =>
    k == 'meetup' ? PostType.meetup : PostType.free;

class Post {
  final String id;
  final PostType type;
  final String title;
  final String? content;
  final bool anonymous;
  final String? authorUid;
  final String? authorName;
  final int createdAt;

  // meetup 전용
  final int? dayMillis;    // 해당 날짜 00:00:00 (로컬)
  final int? startAt;      // epoch millis
  final int? endAt;        // epoch millis
  final String? place;
  final Map<String, bool> attendees; // uid -> true
  final int? capacity;               // 정원 (null=무제한)

  Post({
    required this.id,
    required this.type,
    required this.title,
    required this.createdAt,
    this.content,
    this.anonymous = false,
    this.authorUid,
    this.authorName,
    this.dayMillis,
    this.startAt,
    this.endAt,
    this.place,
    Map<String, bool>? attendees,
    this.capacity,
  }) : attendees = attendees ?? const {};

  Map<String, dynamic> toJson() {
    return {
      'type': type.key,
      'title': title,
      'content': content,
      'anonymous': anonymous,
      'authorUid': authorUid,
      'authorName': authorName,
      'createdAt': createdAt,
      'dayMillis': dayMillis,
      'startAt': startAt,
      'endAt': endAt,
      'place': place,
      'attendees': attendees.isEmpty ? null : attendees,
      'capacity': capacity,
    };
  }

  factory Post.fromMap(String id, Map raw) {
    final m = Map<String, dynamic>.from(raw);
    final atts = <String, bool>{};
    if (m['attendees'] is Map) {
      Map<String, dynamic>.from(m['attendees']).forEach((k, v) {
        if (v == true) atts[k] = true;
      });
    }
    return Post(
      id: id,
      type: postTypeFromKey((m['type'] ?? 'free') as String),
      title: (m['title'] ?? '').toString(),
      content: m['content']?.toString(),
      anonymous: (m['anonymous'] ?? false) == true,
      authorUid: m['authorUid']?.toString(),
      authorName: m['authorName']?.toString(),
      createdAt: (m['createdAt'] ?? 0) as int,
      dayMillis: m['dayMillis'] is int ? (m['dayMillis'] as int) : null,
      startAt: m['startAt'] is int ? (m['startAt'] as int) : null,
      endAt: m['endAt'] is int ? (m['endAt'] as int) : null,
      place: m['place']?.toString(),
      attendees: atts,
      capacity: m['capacity'] is int ? (m['capacity'] as int) : null,
    );
  }
}

/// =======================
/// 모임/자유 통합 보드
/// =======================
class EventBoard extends StatefulWidget {
  final String clubName;
  const EventBoard({super.key, required this.clubName});

  @override
  State<EventBoard> createState() => _EventBoardState();
}

class _EventBoardState extends State<EventBoard> {
  static const accent = Color.fromRGBO(216, 162, 163, 1.0);
  DatabaseReference get _ref =>
      FirebaseDatabase.instance.ref('Club/${widget.clubName}/posts');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _ref.orderByChild('createdAt').onValue,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snap.data?.snapshot.value;
                if (data == null) {
                  return const Center(child: Text('아직 글이 없습니다.'));
                }
                final map = Map<String, dynamic>.from(data as Map);
                final items = map.entries
                    .map((e) => Post.fromMap(e.key, Map<String, dynamic>.from(e.value)))
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // 최신순

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = items[i];
                    final isMeetup = p.type == PostType.meetup;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      leading: isMeetup
                          ? const Icon(Icons.flash_on_outlined, color: Colors.amber)
                          : const Icon(Icons.forum_outlined, color: Colors.grey),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isMeetup)
                            Text(
                              _fmtMeetupLine(p),
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                            ),
                          if (!isMeetup && (p.content?.isNotEmpty ?? false))
                            Text(
                              p.content!,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            _authorLine(p),
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          )
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => PostDetailPage(clubName: widget.clubName, post: p),
                        ));
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: SizedBox(
            width: 100,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () async {
                final created = await Navigator.of(context).push<Post>(
                  MaterialPageRoute(
                    builder: (_) => PostEditorPage(clubName: widget.clubName),
                  ),
                );
                if (created != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('글이 등록되었습니다.')),
                  );
                }
              },
              icon: const Icon(Icons.edit),
              label: const Text('글 쓰기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _authorLine(Post p) {
    final created = DateTime.fromMillisecondsSinceEpoch(p.createdAt);
    final ts = '${created.month.toString().padLeft(2, "0")}/${created.day.toString().padLeft(2, "0")} '
        '${created.hour.toString().padLeft(2, "0")}:${created.minute.toString().padLeft(2, "0")}';
    final name = p.anonymous ? '익명' : (p.authorName ?? p.authorUid ?? '-');
    return '$name · $ts';
  }

  String _fmtMeetupLine(Post p) {
    final day = DateTime.fromMillisecondsSinceEpoch((p.dayMillis ?? p.startAt) ?? p.createdAt);
    final d = '${day.month.toString().padLeft(2,"0")}.${day.day.toString().padLeft(2,"0")}'; // 연도 제거
    final sh = p.startAt != null ? _fmtHM(DateTime.fromMillisecondsSinceEpoch(p.startAt!)) : '--:--';
    final eh = p.endAt != null ? _fmtHM(DateTime.fromMillisecondsSinceEpoch(p.endAt!)) : '--:--';
    final joined = p.attendees.length;
    final cap = p.capacity;
    final capStr = cap != null ? ' · 참여 $joined/$cap명' : ' · 참여 $joined명';
    final place = (p.place?.isNotEmpty ?? false) ? ' · 장소 ${p.place}' : '';
    final closed = (cap != null && joined >= cap) ? ' · 마감' : '';
    return '$d $sh–$eh$place$capStr$closed';
  }

  String _fmtHM(DateTime dt) =>
      '${dt.hour.toString().padLeft(2,"0")}:${dt.minute.toString().padLeft(2,"0")}';
}

/// 작은 타입 칩
class _TypeChip extends StatelessWidget {
  final PostType type;
  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final isMeetup = type == PostType.meetup;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isMeetup ? const Color(0xFFFFF2F4) : const Color(0xFFF2F6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isMeetup ? const Color(0xFFFFC7CF) : const Color(0xFFBBD3FF)),
      ),
      child: Text(type.label, style: TextStyle(fontSize: 12, color: isMeetup ? Colors.pink : Colors.blue)),
    );
  }
}

/// =======================
/// 글 상세
/// =======================
class PostDetailPage extends StatelessWidget {
  final String clubName;
  final Post post;
  const PostDetailPage({super.key, required this.clubName, required this.post});

  static const accent = Color.fromRGBO(216, 162, 163, 1.0);

  DatabaseReference get _ref =>
      FirebaseDatabase.instance.ref('Club/$clubName/posts/${post.id}');

  bool _isAuthor(Post p) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && uid == p.authorUid;
  }

  String _fmtTs(int ms) {
    final ts = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${ts.month.toString().padLeft(2, "0")}/${ts.day.toString().padLeft(2, "0")} '
        '${ts.hour.toString().padLeft(2, "0")}:${ts.minute.toString().padLeft(2, "0")}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _ref.onValue,
      builder: (context, snap) {
        final raw = snap.data?.snapshot.value;
        final p = (raw == null)
            ? post
            : Post.fromMap(post.id, Map<String, dynamic>.from(raw as Map));

        return Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: true, // 키보드에 따라 본문 밀어올림
          appBar: AppBar(
            backgroundColor: Colors.white,
            actions: [
              if (_isAuthor(p))
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      final updated = await Navigator.of(context).push<Post>(
                        MaterialPageRoute(
                          builder: (_) => PostEditorPage(
                            clubName: clubName,
                            initial: p,
                          ),
                        ),
                      );
                      if (updated != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('수정되었습니다.')),
                        );
                      }
                    } else if (v == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('삭제하시겠습니까?'),
                          content: const Text('삭제 후 되돌릴 수 없습니다.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('삭제', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await _ref.remove();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('삭제되었습니다.')),
                          );
                        }
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('수정')),
                    PopupMenuItem(value: 'delete', child: Text('삭제', style: TextStyle(color: Colors.red))),
                  ],
                  icon: const Icon(Icons.more_vert),
                ),
            ],
          ),

          // 본문
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), // 하단 입력창 높이만큼 여유
            children: [
              Align(
                widthFactor: 1.0,
                alignment: Alignment.centerLeft,
                child: _TypeChip(type: p.type),
              ),
              const SizedBox(height: 8),

              // 작성자 + 작성시간
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.anonymous ? '익명' : (p.authorName ?? p.authorUid ?? '-'),
                    style: const TextStyle(color: Colors.grey),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(_fmtTs(p.createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),

              const SizedBox(height: 8),

              // 제목
              Text(
                p.title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
              ),
              const SizedBox(height: 6),

              // 번개모임 상세
              if (p.type == PostType.meetup) ...[
                Text(_meetupDetailLine(p), style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                if (p.place?.isNotEmpty == true)
                  Text('장소: ${p.place}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
              ],

              // 본문
              if (p.content?.isNotEmpty == true)
                Text(p.content!, style: const TextStyle(height: 1.5)),

              const SizedBox(height: 8),

              if (p.type == PostType.meetup)
                _JoinToggleLive(base: _ref.child('attendees')),

              // 댓글 목록
              CommentsSection(clubName: clubName, postId: p.id),
            ],
          ),

          // === 하단 고정 댓글 입력창 ===
          bottomSheet: SafeArea(
            top: false,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _CommentComposer(
                clubName: clubName,
                postId: p.id,
                accent: accent,
              ),
            ),
          ),
        );
      },
    );
  }

  String _meetupDetailLine(Post p) {
    final day = DateTime.fromMillisecondsSinceEpoch((p.dayMillis ?? p.startAt) ?? p.createdAt);
    final d = '${day.month.toString().padLeft(2,"0")}.${day.day.toString().padLeft(2,"0")}';
    String _fmtHM(DateTime dt) =>
        '${dt.hour.toString().padLeft(2,"0")}:${dt.minute.toString().padLeft(2,"0")}';
    final sh = p.startAt != null ? _fmtHM(DateTime.fromMillisecondsSinceEpoch(p.startAt!)) : '--:--';
    final eh = p.endAt != null ? _fmtHM(DateTime.fromMillisecondsSinceEpoch(p.endAt!)) : '--:--';

    final joined = p.attendees.length;
    final cap = p.capacity;
    final cnt = cap != null ? '참여 $joined/$cap명' : '참여 $joined명';
    final closed = (cap != null && joined >= cap) ? ' · 마감' : '';

    return '$d $sh–$eh · $cnt$closed';
  }
}

/// 상세에서 실시간 RSVP 토글 (정원 체크 + 자동 마감)
class _JoinToggleLive extends StatefulWidget {
  final DatabaseReference base; // posts/{id}/attendees
  const _JoinToggleLive({required this.base});

  @override
  State<_JoinToggleLive> createState() => _JoinToggleLiveState();
}

class _JoinToggleLiveState extends State<_JoinToggleLive> {
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) return const SizedBox.shrink();

    // posts/{id} 전체를 구독해서 capacity + attendees 동시 반영
    final postRef = widget.base.parent!;
    return StreamBuilder<DatabaseEvent>(
      stream: postRef.onValue,
      builder: (context, snap) {
        final m = (snap.data?.snapshot.value is Map)
            ? Map<String, dynamic>.from(snap.data!.snapshot.value as Map)
            : <String, dynamic>{};

        final attendeesMap = (m['attendees'] is Map)
            ? Map<String, dynamic>.from(m['attendees'])
            : <String, dynamic>{};

        final joined = attendeesMap[_uid] == true;
        final joinedCount = attendeesMap.length;
        final cap = (m['capacity'] is int) ? m['capacity'] as int : null;
        final full = (cap != null && joinedCount >= cap);

        // 상태별 라벨/비활성화
        String label;
        if (joined) {
          label = '참여 취소';
        } else if (full) {
          label = '마감';
        } else {
          label = '참여하기';
        }

        final disabled = !joined && full; // 마감이면 새 참여 불가, 이미 참여한 사람은 취소 가능

        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: disabled
                ? Colors.grey.shade300
                : const Color.fromRGBO(209, 87, 90, 1.0),
            foregroundColor: disabled ? Colors.grey.shade700 : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: disabled
              ? null
              : () async {
            final myRef = widget.base.child(_uid!);

            if (joined) {
              await myRef.remove();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('참여 취소됨')),
                );
              }
              return;
            }

            // ── 레이스 컨디션 방지: 마지막에 한 번 더 체크 ──
            final capSnap = await postRef.child('capacity').get();
            final attSnap = await widget.base.get();
            final latestCap = (capSnap.exists && capSnap.value is int) ? capSnap.value as int : null;
            final latestCount = (attSnap.value is Map) ? (attSnap.value as Map).length : 0;

            if (latestCap != null && latestCount >= latestCap) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('정원이 가득 찼습니다.')),
                );
              }
              return;
            }

            await myRef.set(true);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('참여 완료')),
              );
            }
          },
          icon: Icon(joined ? Icons.close : Icons.check),
          label: Text(label),
        );
      },
    );
  }
}

/// =======================
/// 글 작성/수정
/// =======================
class PostEditorPage extends StatefulWidget {
  final String clubName;
  final Post? initial; // null=생성
  const PostEditorPage({super.key, required this.clubName, this.initial});
  bool get isEdit => initial != null;

  @override
  State<PostEditorPage> createState() => _PostEditorPageState();
}

class _PostEditorPageState extends State<PostEditorPage> {
  static const accent = Color.fromRGBO(216, 162, 163, 1.0);

  final _titleC = TextEditingController();
  final _contentC = TextEditingController();
  final _placeC = TextEditingController();
  final _capacityC = TextEditingController(); // ← 정원 입력

  PostType _type = PostType.free;
  bool _anonymous = false;

  DateTime? _day;          // 날짜 1개
  TimeOfDay? _startTime;   // 시작 시각
  TimeOfDay? _endTime;     // 종료 시각

  bool _saving = false;

  DatabaseReference get _ref =>
      FirebaseDatabase.instance.ref('Club/${widget.clubName}/posts');

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      final p = widget.initial!;
      _titleC.text = p.title;
      _contentC.text = p.content ?? '';
      _placeC.text = p.place ?? '';
      _capacityC.text = p.capacity?.toString() ?? '';
      _type = p.type;
      _anonymous = p.anonymous;
      if (p.dayMillis != null) {
        final d = DateTime.fromMillisecondsSinceEpoch(p.dayMillis!);
        _day = DateTime(d.year, d.month, d.day);
      } else if (p.startAt != null) {
        final s = DateTime.fromMillisecondsSinceEpoch(p.startAt!);
        _day = DateTime(s.year, s.month, s.day);
      }
      if (p.startAt != null) {
        final s = DateTime.fromMillisecondsSinceEpoch(p.startAt!);
        _startTime = TimeOfDay(hour: s.hour, minute: s.minute);
      }
      if (p.endAt != null) {
        final e = DateTime.fromMillisecondsSinceEpoch(p.endAt!);
        _endTime = TimeOfDay(hour: e.hour, minute: e.minute);
      }
    }
  }

  @override
  void dispose() {
    _titleC.dispose();
    _contentC.dispose();
    _placeC.dispose();
    _capacityC.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _day ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (d != null) setState(() => _day = DateTime(d.year, d.month, d.day));
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (t != null) setState(() => _startTime = t);
  }

  Future<void> _pickEnd() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay(hour: (TimeOfDay.now().hour + 1) % 24, minute: TimeOfDay.now().minute),
    );
    if (t != null) setState(() => _endTime = t);
  }

  Future<void> _save() async {
    final title = _titleC.text.trim();
    if (title.isEmpty) {
      _toast('제목을 입력해 주세요.'); return;
    }

    int? dayMillis;
    int? startAt;
    int? endAt;
    int? capacity;
    final place = _placeC.text.trim().isEmpty ? null : _placeC.text.trim();
    final content = _contentC.text.trim().isEmpty ? null : _contentC.text.trim();

    if (_capacityC.text.trim().isNotEmpty) {
      final v = int.tryParse(_capacityC.text.trim());
      if (v == null || v <= 0) {
        _toast('최대 인원은 1 이상의 숫자로 입력하세요.');
        return;
      }
      capacity = v;
    }

    if (_type == PostType.meetup) {
      if (_day == null) { _toast('날짜를 선택해 주세요.'); return; }
      if (_startTime == null || _endTime == null) { _toast('시작/종료 시간을 선택해 주세요.'); return; }

      final s = _combine(_day!, _startTime!);
      final e = _combine(_day!, _endTime!);
      if (!e.isAfter(s)) { _toast('종료 시간이 시작 시간보다 뒤여야 합니다.'); return; }

      dayMillis = DateTime(_day!.year, _day!.month, _day!.day).millisecondsSinceEpoch;
      startAt = s.millisecondsSinceEpoch;
      endAt = e.millisecondsSinceEpoch;
    }

    Future<String?> _resolveAuthorName() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final email = user.email;
      if (email == null || email.isEmpty) {
        return user.displayName; // fallback
      }
      try {
        final snap = await FirebaseDatabase.instance
            .ref('Person')
            .orderByChild('email')
            .equalTo(email)
            .limitToFirst(1)
            .get();

        if (!snap.exists) {
          return user.displayName ?? email;
        }

        final map = Map<Object?, Object?>.from(snap.value as Map);
        final first = Map<Object?, Object?>.from(map.values.first as Map);
        final name = first['name']?.toString();

        return (name != null && name.isNotEmpty)
            ? name
            : (user.displayName ?? email);
      } catch (_) {
        return user.displayName ?? email;
      }
    }

    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final authorUid = user?.uid;
      final authorName = await _resolveAuthorName();
      if (widget.isEdit) {
        final id = widget.initial!.id;
        await _ref.child(id).update({
          'type': _type.key,
          'title': title,
          'content': content,
          'anonymous': _anonymous,
          'place': place,
          'dayMillis': dayMillis,
          'startAt': startAt,
          'endAt': endAt,
          'capacity': capacity,
        });
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        final newRef = _ref.push();
        final id = newRef.key!;
        await newRef.set({
          'type': _type.key,
          'title': title,
          'content': content,
          'anonymous': _anonymous,
          'authorUid': authorUid,
          'authorName': authorName,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'place': place,
          'dayMillis': dayMillis,
          'startAt': startAt,
          'endAt': endAt,
          'capacity': capacity,
        });
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      _toast('저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  DateTime _combine(DateTime day, TimeOfDay t) =>
      DateTime(day.year, day.month, day.day, t.hour, t.minute);

  @override
  Widget build(BuildContext context) {
    final isMeetup = _type == PostType.meetup;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(widget.isEdit ? '글 수정' : '글 작성'), backgroundColor: Colors.white,),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ToggleButtons(
            isSelected: [_type == PostType.meetup, _type == PostType.free],
            onPressed: (i) => setState(() => _type = i == 0 ? PostType.meetup : PostType.free),
            borderRadius: BorderRadius.circular(12),
            constraints: const BoxConstraints(minHeight: 40, minWidth: 80),
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('번개모임')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('잡담')),
            ],
          ),
          const SizedBox(height: 12),

          SwitchListTile(
            value: _anonymous,
            onChanged: (v) => setState(() => _anonymous = v),
            title: const Text('익명으로 올리기'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _titleC,
            decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),

          if (isMeetup) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDay,
                    icon: const Icon(Icons.today),
                    label: Text(_day == null
                        ? '날짜 선택'
                        : '${_day!.year}.${_day!.month.toString().padLeft(2,"0")}.${_day!.day.toString().padLeft(2,"0")}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickStart,
                    icon: const Icon(Icons.schedule),
                    label: Text(_startTime == null
                        ? '시작 시간'
                        : '${_startTime!.hour.toString().padLeft(2,"0")}:${_startTime!.minute.toString().padLeft(2,"0")}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickEnd,
                    icon: const Icon(Icons.timelapse),
                    label: Text(_endTime == null
                        ? '종료 시간'
                        : '${_endTime!.hour.toString().padLeft(2,"0")}:${_endTime!.minute.toString().padLeft(2,"0")}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              style: const TextStyle(color: Colors.black),
              controller: _placeC,
              decoration: const InputDecoration(
                labelText: '장소(선택)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _capacityC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '최대 인원(선택)',
                hintText: '예: 10',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          TextField(
            controller: _contentC,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: '내용 (선택, 번개모임/잡담 공통)',
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
            label: Text(widget.isEdit ? '수정' : '등록'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent, foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class Comment {
  final String id;
  final String content;
  final bool anonymous;
  final String? authorUid;
  final String? authorName;
  final int createdAt;

  Comment({
    required this.id,
    required this.content,
    required this.createdAt,
    this.anonymous = false,
    this.authorUid,
    this.authorName,
  });

  Map<String, dynamic> toJson() => {
    'content': content,
    'anonymous': anonymous,
    'authorUid': authorUid,
    'authorName': authorName,
    'createdAt': createdAt,
  };

  factory Comment.fromMap(String id, Map raw) {
    final m = Map<String, dynamic>.from(raw);
    return Comment(
      id: id,
      content: (m['content'] ?? '').toString(),
      anonymous: (m['anonymous'] ?? false) == true,
      authorUid: m['authorUid']?.toString(),
      authorName: m['authorName']?.toString(),
      createdAt: (m['createdAt'] ?? 0) as int,
    );
  }
}

/// 댓글 목록만 표시 (입력은 bottomSheet의 _CommentComposer에서)
class CommentsSection extends StatelessWidget {
  final String clubName;
  final String postId;
  const CommentsSection({super.key, required this.clubName, required this.postId});

  DatabaseReference get _base =>
      FirebaseDatabase.instance.ref('Club/$clubName/posts/$postId/comments');

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 20),
        StreamBuilder<DatabaseEvent>(
          stream: _base.orderByChild('createdAt').onValue,
          builder: (context, snap) {
            final raw = snap.data?.snapshot.value;
            if (raw == null) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('첫 댓글을 남겨보세요.'),
                ),
              );
            }
            final map = Map<String, dynamic>.from(raw as Map);
            final items = map.entries
                .map((e) => Comment.fromMap(e.key, Map<String, dynamic>.from(e.value)))
                .toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt)); // 오래된 순

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = items[i];
                final name = c.anonymous ? '익명' : (c.authorName ?? c.authorUid ?? '-');
                final ts = DateTime.fromMillisecondsSinceEpoch(c.createdAt);
                final tstr =
                    '${ts.month.toString().padLeft(2, "0")}/${ts.day.toString().padLeft(2, "0")} '
                    '${ts.hour.toString().padLeft(2, "0")}:${ts.minute.toString().padLeft(2, "0")}';

                final isMine = FirebaseAuth.instance.currentUser?.uid == c.authorUid;

                return ListTile(
                  dense: true,
                  title: Text(c.content),
                  subtitle: Text('$name · $tstr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: isMine
                      ? _DeleteCommentButton(
                    clubName: clubName,
                    postId: postId,
                    commentId: c.id,
                  )
                      : null,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _DeleteCommentButton extends StatelessWidget {
  final String clubName;
  final String postId;
  final String commentId;
  const _DeleteCommentButton({
    required this.clubName,
    required this.postId,
    required this.commentId,
  });

  @override
  Widget build(BuildContext context) {
    final base = FirebaseDatabase.instance
        .ref('Club/$clubName/posts/$postId/comments');
    return IconButton(
      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
      onPressed: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('댓글 삭제'),
            content: const Text('삭제 후 되돌릴 수 없습니다.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (ok == true) {
          await base.child(commentId).remove();
        }
      },
    );
  }
}

/// 하단 고정: 댓글 입력 컴포저
class _CommentComposer extends StatefulWidget {
  final String clubName;
  final String postId;
  final Color accent;
  const _CommentComposer({
    required this.clubName,
    required this.postId,
    required this.accent,
  });

  @override
  State<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<_CommentComposer> {
  final _c = TextEditingController();
  bool _anon = false;
  bool _posting = false;

  DatabaseReference get _base =>
      FirebaseDatabase.instance.ref('Club/${widget.clubName}/posts/${widget.postId}/comments');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<String?> _resolveAuthorName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final email = user.email;
    if (email == null || email.isEmpty) {
      return user.displayName;
    }
    try {
      final snap = await FirebaseDatabase.instance
          .ref('Person')
          .orderByChild('email')
          .equalTo(email)
          .limitToFirst(1)
          .get();
      if (!snap.exists) {
        return user.displayName ?? email;
      }
      final map = Map<Object?, Object?>.from(snap.value as Map);
      final first = Map<Object?, Object?>.from(map.values.first as Map);
      final name = first['name']?.toString();
      return (name != null && name.isNotEmpty) ? name : (user.displayName ?? email);
    } catch (_) {
      return user.displayName ?? email;
    }
  }

  Future<void> _send() async {
    final txt = _c.text.trim();
    if (txt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('댓글을 입력해 주세요.')));
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }
    setState(() => _posting = true);
    try {
      final newRef = _base.push();
      await newRef.set({
        'content': txt,
        'anonymous': _anon,
        'authorUid': user.uid,
        'authorName': _anon ? null : await _resolveAuthorName(),
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      _c.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('등록 실패: $e')));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      minLines: 1,
      maxLines: 4,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        isDense: true,
        hintText: _anon ? '익명으로 댓글을 입력하세요' : '댓글을 입력하세요',
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: const Color.fromRGBO(0, 0, 0, 0.15), width: 1),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.grey, width: 1),
        ),
        floatingLabelStyle: const TextStyle(
          color: Color.fromRGBO(119, 119, 119, 1.0),
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),

        // 왼쪽: 익명 토글 (글자 굵기 변경)
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() => _anon = !_anon),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: _anon ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 14,
                ),
                child: const Text('익명'),
              ),
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),

        // 오른쪽: 등록 버튼/로딩
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: _posting
              ? const SizedBox(
            height: 24, width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : TextButton(
            onPressed: _send,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: widget.accent,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('등록'),
          ),
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
  }
}
