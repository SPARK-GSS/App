import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:gss/pages/mainpage.dart';
import 'package:gss/pages/mypage.dart';
import 'package:gss/pages/search.dart';
import 'package:gss/services/AuthService.dart';



class homepage extends StatefulWidget {
  const homepage({super.key});

  @override
  _homepageState createState() => _homepageState();
}

class _homepageState extends State<homepage> {
  int _selectedIndex = 0;
  

  void _navigateBottomBar(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<Widget> _pages = [UserMain(), UserSearch(), UserMy()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Container(child: Text('GSS'))),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _navigateBottomBar,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Main'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'MyPage'),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: FutureBuilder<String>(
              future: user_name(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Text('로딩 중...');
                } else if (snapshot.hasError) {
                  return Text('에러 발생');
                } else {
                  return Text(snapshot.data ?? '이름 없음');
                }
              },
            ),
              accountEmail: Text(user_email()!),
              currentAccountPicture: CircleAvatar(
                backgroundImage: AssetImage('assets/google.jpg'),
                backgroundColor: Colors.white,
              ),
              onDetailsPressed: () {
                print("arrow is clicked");
              },
              decoration: BoxDecoration(
                color: Colors.red[200],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40.0),
                  bottomRight: Radius.circular(40.0),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home, color: Colors.grey[850]),
              title: Text('main'),
              onTap: () {
                print("main is clicked");
              },
            ),
            ListTile(
              leading: Icon(Icons.search, color: Colors.grey[850]),
              title: Text('search'),
              onTap: () {
                print("search is clicked");
              },
            ),
            ListTile(
              leading: Icon(Icons.settings, color: Colors.grey[850]),
              title: Text('setting'),
              onTap: () {
                print("setting is clicked");
              },
            ),
          ],
        ),
      ),
    );
  }
}
