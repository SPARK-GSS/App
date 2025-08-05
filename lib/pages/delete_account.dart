import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gss/pages/login.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _deleteAccount() async {
    final user = _auth.currentUser;
    final password = _passwordController.text.trim();
    final email = user?.email;

    if (email == null || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호를 입력해주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 재인증
      final credential = EmailAuthProvider.credential(email: email, password: password);
      await user!.reauthenticateWithCredential(credential);

      // 탈퇴 확인 다이얼로그
      bool confirmed = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("정말 탈퇴하시겠습니까?"),
          content: const Text("이 작업은 되돌릴 수 없습니다."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text("탈퇴", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed) {
        await user.delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("계정이 삭제되었습니다.")),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Login()),
              (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = "알 수 없는 오류가 발생했습니다.";
      if (e.code == 'wrong-password') {
        message = "비밀번호가 일치하지 않습니다.";
      } else if (e.code == 'user-mismatch' || e.code == 'user-not-found') {
        message = "계정을 다시 확인해주세요.";
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
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text("회원 탈퇴")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (user?.email != null)
              Text("현재 계정: ${user!.email}", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "비밀번호 입력"),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _deleteAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text("계정 삭제"),
            ),
          ],
        ),
      ),
    );
  }
}
