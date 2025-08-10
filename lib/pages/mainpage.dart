import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:gss/homepage.dart';

import 'package:gss/mainpages/noticeboard.dart';
import 'package:gss/mainpages/calendar.dart';
import 'package:gss/mainpages/event.dart';
import 'package:gss/mainpages/group.dart';
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
      appBar: AppBar(
        title: const Text('내 동아리'),
        actions: [
          IconButton(
            onPressed: () {
              print("plus");
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
              onTap: () {
                print("${club[i]}");
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (context) => Club(clubName: '${club[i]}')));
              },
              leading: CircleAvatar(
                radius: 20,
                backgroundImage: AssetImage('assets/${club[i]}.png'),
                backgroundColor: Colors.grey[200],
              ),
              title: Text(club[i]),
              trailing: FutureBuilder<String>(
                future: user_status(club[i]),
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
                    return Text(snapshot.data ?? '');
                  }
                },
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // 탭 개수
      child: Scaffold(
        appBar: AppBar(
          title: const Text('상단 메뉴 예시'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '모임'),
              Tab(text: '정산'),
              Tab(text: '공지'),
              Tab(text: '캘린더'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            //Group(clubName: widget.clubName),
            Center(child: Text('모임 페이지')),
            Center(child: Text('정산 페이지')),
            NoticeBoard(clubName: widget.clubName),
            Calendar(clubName: widget.clubName)
          ],
        ),
      ),
    );
  }
}
