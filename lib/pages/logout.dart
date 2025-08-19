import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:gss/pages/login.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:gss/pages/login.dart';

class LogOutButton extends StatelessWidget {
  const LogOutButton({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      // Firebase 로그아웃
      await FirebaseAuth.instance.signOut();

      // Google 로그아웃
      await GoogleSignIn.instance.signOut();

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
    return Center(
      child: SizedBox(
        width: 120,
        height: 45,
        child: ElevatedButton(
          onPressed: () async {
            final result = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("로그아웃"),
                content: const Text("로그아웃 하시겠습니까?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false), // 취소
                    child: const Text("취소"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true), // 확인
                    child: const Text("확인"),
                  ),
                ],
              ),
            );

            if (result == true) {
              _logout(context); // ✅ 팝업에서 확인 누르면 로그아웃 실행
            }
          },
          child: const Text("로그아웃"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(209, 87, 90, 1.0),
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

}
