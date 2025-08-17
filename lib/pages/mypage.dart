import 'package:flutter/material.dart';
import 'package:gss/pages/delete_account.dart';
import 'package:gss/pages/logout.dart';
import 'package:gss/pages/change_password.dart';
// import 'package:gss/pages/notification_settings.dart';
// import 'package:gss/pages/friends.dart';
// import 'package:gss/pages/theme_settings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

// 이메일 가져오기
String? _userEmail() {
  final user = FirebaseAuth.instance.currentUser;
  return user?.email;
}

// 이름 가져오기
Future<String?> _userName() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final snap = await FirebaseDatabase.instance
      .ref('Person')
      .orderByChild('email')
      .equalTo(user.email)
      .limitToFirst(1)
      .get();

  if (!snap.exists) return null;

  final map = Map<Object?, Object?>.from(snap.value as Map);
  final first = Map<Object?, Object?>.from(map.values.first as Map);
  return first['name']?.toString();
}


class UserMy extends StatelessWidget {
  const UserMy({super.key});


  @override
  Widget build(BuildContext context) {
    final email = _userEmail();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('마이 페이지',style:TextStyle(fontFamily: "Pretendard",fontWeight: FontWeight.w700)),
        centerTitle: true,toolbarHeight: 40),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FutureBuilder<String?> (
            future: _userName(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const CircularProgressIndicator();
              }
              if (snapshot.hasError) {
                return const Text('이름 불러오기 오류');
              }
              return Text('${snapshot.data ?? '없음'}',textAlign: TextAlign.center, style: TextStyle(fontSize: 20,fontWeight: FontWeight.w700), );
            },
          ),
          const SizedBox(height: 5),
          Text('메일: ${email ?? '없음'}', textAlign: TextAlign.center, style: TextStyle(color: Color.fromRGBO(
              216, 162, 163, 1.0)),),
          const SizedBox(height: 10),
          _buildSettingButton(
            context,
            title: '프로필 수정',
            backgroundColor: Color.fromRGBO(216, 162, 163, 1.0) ,
            foregroundColor: Colors.white,
            alignment: Alignment.center,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChangePasswordPage()));
              },
          ),
          const SizedBox(height: 30),
          const Text(
            '계정 설정',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildSettingButton(
            context,
            title: '비밀번호 변경',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChangePasswordPage()));
            },
          ),
          _buildSettingButton(
            context,
            title: '로그아웃',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LogOutPage()),
              );
            },
          ),
          _buildSettingButton(
            context,
            title: '회원 탈퇴',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DeleteAccountPage()),
              );
            },
          ),
          const SizedBox(height: 30),
          const Text(
            '앱 설정',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildSettingButton(
            context,
            title: '알림 설정',
            onPressed: () {
              // Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationSettingsPage()));
            },
          ),
          _buildSettingButton(
            context,
            title: '친구 관리',
            onPressed: () {
              // Navigator.push(context, MaterialPageRoute(builder: (_) => FriendsPage()));
            },
          ),
          _buildSettingButton(
            context,
            title: '다크모드',
            onPressed: () {
              // Navigator.push(context, MaterialPageRoute(builder: (_) => ThemeSettingsPage()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingButton(BuildContext context,
      {required String title, required VoidCallback onPressed,
      Color backgroundColor = const Color.fromRGBO(221, 221, 221, 1.0),
      Color foregroundColor = const Color.fromRGBO(119, 119, 119, 1.0),
        Alignment alignment = Alignment.centerLeft,}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          alignment: alignment,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        onPressed: onPressed,
        child: Text(title, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
