import 'package:flutter/material.dart';
import 'package:gss/services/DBservice.dart';
import 'package:gss/pages/delete_account.dart';
import 'package:gss/pages/logout.dart';

class UserMy extends StatelessWidget {
  const UserMy({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // TextButton(
          //   onPressed: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (_) => const LogOutPage()),
          //     );
          //   },
          //   style: TextButton.styleFrom(
          //     foregroundColor: Colors.black,
          //   ),
          //   child: Text(
          //     '로그아웃',
          //     style: TextStyle(
          //         fontSize: 20.0
          //     ),
          //   ),
          // ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DeleteAccountPage()),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.black,
            ),
            child: Text(
              '회원 탈퇴',
              style: TextStyle(
                fontSize: 20.0
              ),
            ),
          )

        ],
      ),
    );
  }
}