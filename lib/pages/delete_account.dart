import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:gss/pages/login.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:gss/services/AuthService.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  bool _isLoading = false;

  Future<void> _deleteAccount() async {
    final user = _auth.currentUser;
    final email = user?.email;

    if (user == null || email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("로그인 정보를 불러올 수 없습니다.")),
      );
      return;
    }

    final isGoogleUser =
    user.providerData.any((info) => info.providerId == 'google.com');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("정말 탈퇴하시겠습니까?"),
        content: const Text("계정과 관련된 모든 데이터가 삭제됩니다."),
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

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final uid = user.uid;

      if (isGoogleUser) {
        // ✅ Google 사용자 재인증
        final googleUser = await GoogleSignIn.instance.authenticate();
        final idToken = googleUser.authentication.idToken;

        final auth = await googleUser.authorizationClient
            .authorizationForScopes(['email', 'profile']);

        final accessToken = auth?.accessToken;

        final credential = GoogleAuthProvider.credential(
          idToken: idToken,
          accessToken: accessToken,
        );

        await user.reauthenticateWithCredential(credential);

        await user.reauthenticateWithCredential(credential);
      } else {
        // ✅ 이메일 사용자 재인증
        final password = _passwordController.text.trim();
        if (password.isEmpty) {
          throw FirebaseAuthException(code: 'empty-password');
        }

        final credential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
      }

      // ✅ Realtime Database에서 사용자 데이터 삭제
      final stuid = await user_stuid(); // AuthService에서 정의한 사용자 학번 추출 함수
      await _database.ref("Person/$stuid").remove();

      // ✅ Firebase Authentication 계정 삭제
      await user.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("계정이 성공적으로 삭제되었습니다.")),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Login()),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message = "계정 삭제에 실패했습니다.";
      switch (e.code) {
        case 'wrong-password':
          message = "비밀번호가 일치하지 않습니다.";
          break;
        case 'requires-recent-login':
          message = "다시 로그인 후 시도해주세요.";
          break;
        case 'user-mismatch':
        case 'user-not-found':
          message = "사용자 정보를 다시 확인해주세요.";
          break;
        case 'empty-password':
          message = "비밀번호를 입력해주세요.";
          break;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("예상치 못한 오류가 발생했습니다.")),
      );
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
    final isGoogleUser =
        user?.providerData.any((info) => info.providerId == 'google.com') ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("회원 탈퇴"),backgroundColor: Colors.white,),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // 세로축 중앙 정렬
          crossAxisAlignment: CrossAxisAlignment.center, // 가로축 중앙 정렬
          children: [
            if (user?.email != null)
              Text("현재 계정: ${user!.email}", style: const TextStyle(fontSize: 16, color: Color.fromRGBO(
                  216, 162, 163, 1.0))),
            const SizedBox(height: 20),
            if (!isGoogleUser)

            TextField(
              controller:  _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "비밀번호 입력",
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
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _deleteAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromRGBO(209, 87, 90, 1.0),
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
