import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:gss/services/DBservice.dart';

class UserMain extends StatelessWidget {
  const UserMain({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child:  ClubPage(),
    );
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
      }
      else{
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
      appBar: AppBar(title: const Text('내 동아리')),
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
            itemBuilder: (_, i) => ListTile(title: Text(club[i])),
          );
        },
      ),
    );
  }
}
