import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:gss/pages/mainpage.dart';
import 'package:gss/pages/mypage.dart';
import 'package:gss/pages/search.dart';
import 'package:gss/services/AuthService.dart';
import 'package:gss/chat/chat_list.dart';

// 공지 보드로 이동
import 'package:gss/mainpages/noticeboard.dart';

class homepage extends StatefulWidget {
  const homepage({super.key});

  @override
  _homepageState createState() => _homepageState();
}

class _homepageState extends State<homepage> {
  int _selectedIndex = 0;

  void _navigateBottomBar(int index) {
    setState(() => _selectedIndex = index);
  }

  final List<Widget> _pages = [UserMain(), ClubListPage(), ChatListPage(), UserMy()];

  @override
  Widget build(BuildContext context) {
    const accent = Color.fromRGBO(216, 162, 163, 1.0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('c:lover'),
        toolbarHeight: 40,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: _navigateBottomBar,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: accent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Main'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'MyPage'),
        ],
      ),
      drawer: const Drawer(
        backgroundColor: Colors.white,
        child: _DrawerBody(),
      ),
    );
  }
}

class _DrawerBody extends StatelessWidget {
  const _DrawerBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: const [
        _DrawerHeader(),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('내 동아리 최신 공지', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        MyClubsNoticesDrawerSection(),
        SizedBox(height: 24),
      ],
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    const accent = Color.fromRGBO(216, 162, 163, 1.0);

    return UserAccountsDrawerHeader(
      accountName: FutureBuilder<String>(
        future: user_name(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Text('로딩 중...');
          } else if (snapshot.hasError) {
            return const Text('에러 발생');
          } else {
            return Text(snapshot.data ?? '이름 없음');
          }
        },
      ),
      accountEmail: Text(user_email() ?? ''),
      currentAccountPicture: Builder(
        builder: (_) {
          final url = FirebaseAuth.instance.currentUser?.photoURL;
          return CircleAvatar(
            backgroundColor: Colors.white,
            backgroundImage: (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
            child: (url == null || url.isEmpty)
                ? const Icon(Icons.person, color: Colors.grey)
                : null,
          );
        },
      ),
      decoration: const BoxDecoration(color: accent),
    );
  }
}


/// Drawer

class _DrawerNotice {
  final String id;
  final String clubName;
  final String title;
  final String content;
  final List<String> imageUrls;
  final int createdAt;
  final String? author;
  _DrawerNotice({
    required this.id,
    required this.clubName,
    required this.title,
    required this.content,
    required this.imageUrls,
    required this.createdAt,
    this.author,
  });

  factory _DrawerNotice.fromMap(String id, String clubName, Map m) {
    final List<String> imgs = [];
    if (m['imageUrls'] is List) {
      imgs.addAll(List.from(m['imageUrls']).whereType<String>());
    } else if (m['imageUrls'] is Map) {
      imgs.addAll(Map<String, dynamic>.from(m['imageUrls'])
          .values
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty));
    } else if (m['imageUrl'] is String) {
      final s = (m['imageUrl'] as String);
      if (s.isNotEmpty) imgs.add(s);
    }

    return _DrawerNotice(
      id: id,
      clubName: clubName,
      title: (m['title'] ?? '').toString(),
      content: (m['content'] ?? '').toString(),
      imageUrls: imgs,
      createdAt: (m['createdAt'] ?? 0) as int,
      author: m['author'] as String?,
    );
  }
}

class MyClubsNoticesDrawerSection extends StatefulWidget {
  const MyClubsNoticesDrawerSection({super.key});

  @override
  State<MyClubsNoticesDrawerSection> createState() => _MyClubsNoticesDrawerSectionState();
}

class _MyClubsNoticesDrawerSectionState extends State<MyClubsNoticesDrawerSection> {
  late Future<List<_DrawerNotice>> _future;

  Notice _toNotice(_DrawerNotice d) {
    return Notice(
      id: d.id,
      title: d.title,
      content: d.content,
      imageUrls: d.imageUrls,
      createdAt: d.createdAt,
      author: d.author,
    );
  }


  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // 1. email로 Person/{studentId} 찾고
  // 2. Person/{studentId}/club 의 값을 clubName 리스트로 변환
  Future<List<String>> _fetchMyClubsByPersonPath() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final personSnap = await FirebaseDatabase.instance
        .ref('Person')
        .orderByChild('email')
        .equalTo(user.email)
        .limitToFirst(1)
        .get();

    if (!personSnap.exists) return [];

    final personMap = Map<Object?, Object?>.from(personSnap.value as Map);
    final studentId = personMap.keys.first.toString();

    final clubSnap = await FirebaseDatabase.instance.ref('Person/$studentId/club').get();
    if (!clubSnap.exists) return [];

    final clubMap = Map<Object?, Object?>.from(clubSnap.value as Map);

    return clubMap.values.map((e) => e.toString()).toList();
  }

  // 각 클럽에서 최신 공지 N개씩 모아오고 createdAt 역정렬
  Future<List<_DrawerNotice>> _load() async {
    final clubs = await _fetchMyClubsByPersonPath();
    if (clubs.isEmpty) return [];

    const perClub = 3; // 동아리별 몇 개씩
    final db = FirebaseDatabase.instance.ref();

    final futures = clubs.map((club) async {
      final snap = await db
          .child('Club/$club/notices')
          .orderByChild('createdAt')
          .limitToLast(perClub)
          .get();

      if (!snap.exists) return <_DrawerNotice>[];

      final map = Map<String, dynamic>.from(snap.value as Map);
      final items = map.entries
          .map((e) => _DrawerNotice.fromMap(e.key, club, Map<String, dynamic>.from(e.value)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return items;
    }).toList();

    final all = (await Future.wait(futures)).expand((e) => e).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return all;
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color.fromRGBO(216, 162, 163, 1.0);

    return FutureBuilder<List<_DrawerNotice>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('공지 불러오기 오류: ${snap.error}', style: TextStyle(color: Colors.red[700])),
          );
        }

        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('가입한 동아리의 새 공지가 없습니다.'),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final n = items[i];
            final thumb = (n.imageUrls.isNotEmpty) ? n.imageUrls.first : null;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              leading: thumb != null
                  ? Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(thumb, width: 48, height: 48, fit: BoxFit.cover),
                  ),
                  if (n.imageUrls.length > 1)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '+${n.imageUrls.length - 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                ],
              )
                  : Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image_not_supported),
              ),
              title: Text(
                '[${n.clubName}] ${n.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                n.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                _fmt(n.createdAt),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () {
                final notice = _toNotice(n);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NoticeDetailPage(
                      notice: notice,
                      clubName: n.clubName,
                    ),
                  ),
                );
              },

            );
          },
        );
      },
    );
  }

  String _fmt(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$mm/$dd $hh:$mi';
  }
}
