import 'package:flutter/material.dart';
import 'package:gss/pages/delete_account.dart';
import 'package:gss/pages/logout.dart';
import 'package:gss/pages/change_password.dart';
// import 'package:gss/pages/notification_settings.dart';
// import 'package:gss/pages/friends.dart';
// import 'package:gss/pages/theme_settings.dart';

class UserMy extends StatelessWidget {
  const UserMy({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
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
      {required String title, required VoidCallback onPressed}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          alignment: Alignment.centerLeft,
          backgroundColor: Colors.grey.shade100,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: Text(title, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
