import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:gss/pages/mainpage.dart';
import 'package:gss/pages/mypage.dart';
import 'package:gss/pages/search.dart';
import 'package:gss/services/AuthService.dart';
import 'package:gss/chat/chat_list.dart';

//풀리퀘점

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

  final List<Widget> _pages = [UserMain(), UserSearch(), ChatListPage(), UserMy()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white,title: Container(child: Text('GSS')),toolbarHeight: 40),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: _navigateBottomBar,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.star,color: Color.fromRGBO(
              172, 172, 172, 1.0)), label: 'Main'),
          BottomNavigationBarItem(icon: Icon(Icons.search,color: Color.fromRGBO(
              172, 172, 172, 1.0)), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline, color: Color.fromRGBO(172,172,172,1.0)), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person,color: Color.fromRGBO(
              172, 172, 172, 1.0)), label: 'MyPage'),
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
