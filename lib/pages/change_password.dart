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
  final _formKey = GlobalKey<FormState>();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  bool _showCurrent = false;
  bool _showNew = false;

  Future<void> _changePassword() async {
    if (_isLoading) return;
    final user = _auth.currentUser;
    final email = user?.email;
    final currentPw = _currentPwController.text.trim();
    final newPw = _newPwController.text.trim();

    // 폼 검증
    if (!_formKey.currentState!.validate()) return;

    // 비밀번호 없는(소셜만) 계정 예외
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("이 계정은 이메일/비밀번호 방식이 아닙니다. 비밀번호 재설정을 사용할 수 없어요.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1) 재인증
      final credential = EmailAuthProvider.credential(email: email, password: currentPw);
      await user!.reauthenticateWithCredential(credential);

      // 2) 새 비밀번호로 변경
      await user.updatePassword(newPw);

      // 3) (옵션) 세션 갱신
      await user.reload();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("비밀번호가 성공적으로 변경되었습니다.")),
      );
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      String message = "비밀번호 변경에 실패했습니다.";
      switch (e.code) {
        case 'wrong-password':
          message = "현재 비밀번호가 틀렸습니다.";
          break;
        case 'weak-password':
          message = "새 비밀번호는 6자 이상이어야 합니다.";
          break;
        case 'too-many-requests':
          message = "요청이 너무 많습니다. 잠시 후 다시 시도해주세요.";
          break;
        case 'network-request-failed':
          message = "네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.";
          break;
        case 'requires-recent-login':
          message = "보안상 최근 로그인 후에 변경할 수 있어요. 다시 로그인한 뒤 시도해주세요.";
          break;
        default:
        // 디버그용: print(e.code);
          message = "오류: ${e.code}";
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("알 수 없는 오류가 발생했습니다.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _currentPwController.dispose();
    _newPwController.dispose();
    super.dispose();
  }

  String? _validateCurrent(String? v) {
    if (v == null || v.trim().isEmpty) return "현재 비밀번호를 입력해주세요.";
    return null;
  }

  String? _validateNew(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return "새 비밀번호를 입력해주세요.";
    if (s.length < 6) return "6자 이상으로 설정해주세요.";
    if (s == _currentPwController.text.trim()) return "현재 비밀번호와 다르게 설정해주세요.";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final inputFill = const Color(0xFFDDDDDD);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("비밀번호 변경"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 현재 비밀번호
                    TextFormField(
                      controller: _currentPwController,
                      obscureText: !_showCurrent,
                      validator: _validateCurrent,
                      cursorColor: const Color.fromRGBO(119, 119, 119, 1.0), // 커서 색 직접 지정
                      decoration: InputDecoration(
                        labelText: "현재 비밀번호",
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(30)),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(30)),
                          borderSide: BorderSide(color: Colors.transparent, width: 1),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(30)),
                          borderSide: BorderSide(
                            color: Colors.transparent,
                            width: 2,
                          ),
                        ),
                        floatingLabelStyle: const TextStyle(
                          color: Color.fromRGBO(119, 119, 119, 1.0),
                          fontWeight: FontWeight.w600,
                        ),
                        labelStyle: TextStyle(color: Colors.grey.shade600),
                        filled: true,
                        fillColor: inputFill,
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _showCurrent = !_showCurrent),
                          icon: Icon(_showCurrent ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 새 비밀번호
                    TextFormField(
                      controller: _newPwController,
                      obscureText: !_showNew,
                      validator: _validateNew,
                      cursorColor: const Color.fromRGBO(119, 119, 119, 1.0), // 커서 색 직접 지정
                      decoration: InputDecoration(
                        labelText: "새 비밀번호",
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(30)),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(30)),
                          borderSide: BorderSide(color: Colors.transparent, width: 1),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(30)),
                          borderSide: BorderSide(
                            color: Colors.transparent,
                            width: 2,
                          ),
                        ),
                        floatingLabelStyle: const TextStyle(
                          color: Color.fromRGBO(119, 119, 119, 1.0),
                          fontWeight: FontWeight.w600,
                        ),
                        labelStyle: TextStyle(color: Colors.grey.shade600),
                        filled: true,
                        fillColor: inputFill,
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _showNew = !_showNew),
                          icon: Icon(_showNew ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    _isLoading
                        ? const CircularProgressIndicator()
                        : SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(216, 162, 163, 1.0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("비밀번호 변경"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}
