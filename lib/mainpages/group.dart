import 'package:flutter/material.dart';
import 'package:gss/services/DBservice.dart';

class Group extends StatefulWidget {
  final String clubName;
  const Group({super.key, required this.clubName});

  @override
  State<Group> createState() => _GroupState();
}

class _GroupState extends State<Group> {

  Future<List<String>>? _groupList;
  @override
  void initState(){
    super.initState();
    _groupList = DBsvc().loadGroups(widget.clubName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Groups")),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.add),
      ),
      body: FutureBuilder(
        future: _groupList,
        builder: (context, snap) {
          if (snap.connectionState!= ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('오류: ${snap.error}'));
          }
          final group = snap.data ?? [];
          if (group.isEmpty) {
            return const Center(child: Text('모임이 없습니다.'));
          }
          return ListView.separated(
            itemBuilder: (_, i) => ListTile(
              onTap: () {
                print("${group[i]}");
                // Navigator.of(
                //   context,
                // ).push(MaterialPageRoute(builder: (context) => {sad})));
              },
              // leading: CircleAvatar(
              //   radius: 20,
              //   backgroundImage: AssetImage('assets/${group[i]}.png'),
              //   backgroundColor: Colors.grey[200],
              // ),
              title: Text(group[i]),
            ),
            separatorBuilder: (_, __) => const Divider(),
            itemCount: group.length,
          );
        }
      ),
    );
  }
}
