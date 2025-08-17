import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _currentPwController = TextEditingController();
  final TextEditingController _newPwController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _changePassword() async {
    final user = _auth.currentUser;
    final email = user?.email;
    final currentPw = _currentPwController.text.trim();
    final newPw = _newPwController.text.trim();

    if (email == null || currentPw.isEmpty || newPw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("모든 필드를 입력해주세요.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 현재 비밀번호로 재인증
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPw,
      );
      await user!.reauthenticateWithCredential(credential);

      // 새 비밀번호로 변경
      await user.updatePassword(newPw);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("비밀번호가 성공적으로 변경되었습니다.")),
      );
      Navigator.of(context).pop(); // 이전 화면으로
    } on FirebaseAuthException catch (e) {
      String message = "비밀번호 변경에 실패했습니다.";
      if (e.code == 'wrong-password') {
        message = "현재 비밀번호가 틀렸습니다.";
      } else if (e.code == 'weak-password') {
        message = "비밀번호는 6자 이상이어야 합니다.";
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _currentPwController.dispose();
    _newPwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("비밀번호 변경"),backgroundColor: Colors.white,),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // 세로축 중앙 정렬
          crossAxisAlignment: CrossAxisAlignment.center, // 가로축 중앙 정렬
          children: [
            TextField(
              controller: _currentPwController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "현재 비밀번호",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                ),
                enabledBorder: OutlineInputBorder(     // 비활성화
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                  borderSide: BorderSide(color: Colors.transparent, width: 1),
                ),
                focusedBorder: OutlineInputBorder(     // 포커스
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                  borderSide: BorderSide(color: Colors.transparent, width: 2),
                ),
                filled: true,
                fillColor: Color(0xFFDDDDDD),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _currentPwController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "새 비밀번호",
                border: OutlineInputBorder(            // 기본 테두리
                  borderRadius: BorderRadius.all(Radius.circular(30)), // 둥근 모서리
                ),
                enabledBorder: OutlineInputBorder(     // 비활성화 상태
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                  borderSide: BorderSide(color: Colors.transparent, width: 1),
                ),
                focusedBorder: OutlineInputBorder(     // 포커스 상태 (커서 들어왔을 때)
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                  borderSide: BorderSide(color: Colors.transparent, width: 2),
                ),
                filled: true,                          // 배경색 활성화
                fillColor: Color(0xFFDDDDDD),           // 배경색 지정
              ),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _changePassword,
              child: const Text("비밀번호 변경"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromRGBO(216, 162, 163, 1.0),
                foregroundColor: Colors.white,
              ),
            )
          ],
        ),
      ),
    );
  }
}
