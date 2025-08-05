import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:gss/pages/login.dart';

class LogOutPage extends StatelessWidget {
  const LogOutPage({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      // Firebase 로그아웃
      await FirebaseAuth.instance.signOut();

      // Google 로그아웃도 필요할 경우
      // final googleSignIn = GoogleSignIn();
      // if (await googleSignIn.isSignedIn()) {
      //   await googleSignIn.signOut();
      // }

      // 로그아웃 후 로그인 화면으로 이동 (스택 초기화)
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("로그아웃 되었습니다.")),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const Login()),
              (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("로그아웃에 실패했습니다.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("로그아웃")),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _logout(context),
          child: const Text("로그아웃"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
