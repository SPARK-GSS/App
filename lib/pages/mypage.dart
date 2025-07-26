import 'package:flutter/material.dart';
import 'package:gss/services/DBservice.dart';

class UserMy extends StatelessWidget {
  const UserMy({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          Container(
            child: Text('Setting'),
            alignment: Alignment.center,
          ),
          Container(
            child: Text('Account'),
            alignment: Alignment.center,
          ),
          Container(
            child: Text('blah blah'),
            alignment: Alignment.center,
          ),
          Center(
          child: ElevatedButton(
            onPressed: () {
              DBsvc().DBwrite();
            },
            child: Text("DBwrite 실행"),
          ),
          ),
                    Center(
          child: ElevatedButton(
            onPressed: () {
              DBsvc().DBread();
            },
            child: Text("DBread 실행"),
          ),
          ),
                              Center(
          child: ElevatedButton(
            onPressed: () {
              DBsvc().DBupdate();
            },
            child: Text("DBupdate 실행"),
          ),
          ),
                              Center(
          child: ElevatedButton(
            onPressed: () {
              DBsvc().DBdelete();
            },
            child: Text("DBdelete 실행"),
          ),
          )
        ],
      ),
    );
  }
}