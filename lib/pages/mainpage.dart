import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:gss/homepage.dart';

import 'package:gss/mainpages/noticeboard.dart';
import 'package:gss/mainpages/memberlist.dart';
import 'package:gss/mainpages/calendar.dart';
import 'package:gss/mainpages/event.dart';
import 'package:gss/mainpages/group.dart';
import 'package:gss/mainpages/sync_cal.dart';
import 'package:gss/pages/newclub.dart';
import 'package:gss/services/ApiService.dart';
import 'package:gss/services/AuthService.dart';
import 'package:gss/services/DBservice.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:collection';

class UserMain extends StatelessWidget {
  const UserMain({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: ClubPage());

  }
}

class ClubPage extends StatefulWidget {
  const ClubPage({super.key});

  @override
  State<ClubPage> createState() => _ClubPageState();
}

class _ClubPageState extends State<ClubPage> {
  Future<List<String>>? _clubFuture;

  @override
  void initState() {
    super.initState();
    _clubFuture = _loadClubs();
  }

  Future _onRefresh() async {
    await Future.delayed(Duration(milliseconds: 1000));
  }

  Future<List<String>> _loadClubs() async {
    try {
      // 로그인(하드코딩)
      // final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
      //   email: 'test@naver.com',
      //   password: 'testtest',
      // );

      // FirebaseAuth.instance
      //   .authStateChanges()
      //   .listen((User? user) {
      //     if (user != null) {
      //       print(user.email);
      //     }
      //   });
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print(user.email);
      } else {
        print("no!!!!!!");
        return [];
      }
      final userSnap = await FirebaseDatabase.instance
          .ref('Person')
          .orderByChild('email')
          .equalTo(user!.email)
          .get();

      if (!userSnap.exists) throw Exception('사용자 정보 없음');

      final userData = (userSnap.value as Map).entries.first;
      final studentId = userData.key;
      print(studentId);
      // 동아리 목록 읽기
      final clubSnap = await FirebaseDatabase.instance
          .ref('Person/$studentId/club')
          .get();

      if (!clubSnap.exists) return [];

      final raw = clubSnap.value as Map;
      return raw.values.map((e) => e.toString()).toList();
    } catch (e) {
      print('에러 발생: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('내 동아리',style:TextStyle(fontFamily: "Pretendard",fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (context) => ClubCreatePage()));
            },
            icon: Icon(Icons.add),
          ),
        ],
      ),
      body: FutureBuilder<List<String>>(
        future: _clubFuture,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('오류: ${snap.error}'));
          }
          final club = snap.data ?? [];
          if (club.isEmpty) {
            return const Center(child: Text('가입된 동아리가 없습니다.'));
          }

          return ListView.separated(
            itemCount: club.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, i) => ListTile(
              contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              onTap: () {
                print("${club[i]}");
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (context) => Club(clubName: '${club[i]}')));
              },
              trailing: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/${club[i]}.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
              leading: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              FutureBuilder<String>(
              future: OfficerService.printingRole(club[i]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                } else if (snapshot.hasError) {
                  return const Icon(Icons.error, color: Colors.red);
                  //Text("${snapshot.error}")
                  //const Icon(Icons.error, color: Colors.red);
                } else {
                  return Text(snapshot.data ?? '',style:TextStyle(fontFamily: "Pretendard", color:Color.fromRGBO(
                      216, 162, 163, 1.0)));
                }
              },
            ),
                  Text(club[i],style:TextStyle(fontFamily: "Pretendard",fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(
                    '동아리 한 줄 소개',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),

            ),
          );
        },
      ),
    );
  }
}

class Club extends StatefulWidget {
  final String clubName; // club 이름 저장
  const Club({super.key, required this.clubName});

  @override
  State<Club> createState() => _ClubState();
}

class _ClubState extends State<Club> {
  late Future<bool> _canSeeMembers;

  @override
  void initState() {
    super.initState();
    // MemberList.dart 안의 ListAuth 사용 (이미 그 파일을 import 하고 있으니 OK)
    _canSeeMembers = OfficerService.canManage(widget.clubName);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _canSeeMembers,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final showMembers = snap.data ?? false;

        // 동적으로 탭/뷰 구성
        final tabs = <Tab>[
          const Tab(text: '모임'),
          const Tab(text: '정산'),
          const Tab(text: '공지'),
          const Tab(text: '캘린더'),
          if (showMembers) const Tab(text: '부원'),
        ];

        final views = <Widget>[
          const Center(child: Text('모임 페이지')),
          const Center(child: Text('정산 페이지')),
          NoticeBoard(clubName: widget.clubName),
          CalendarApp(clubName: widget.clubName),
          if (showMembers) MemberList(clubName: widget.clubName),
        ];

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.clubName),
              bottom: TabBar(
                isScrollable: true,
                tabs: tabs,
              ),
            ),
            body: TabBarView(children: views),
          ),
        );
      },
    );
  }
}
