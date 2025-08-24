import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:gss/services/AuthService.dart';

class ClubListPage extends StatefulWidget {
  @override
  State<ClubListPage> createState() => _ClubListPageState();
}

class _ClubListPageState extends State<ClubListPage> {
  final DatabaseReference _clubRef = FirebaseDatabase.instance.ref('Club/');
  List<Map<String, dynamic>> _allClubs = [];
  List<Map<String, dynamic>> _filteredClubs = [];
  Set<int> _selectedClubs = {}; 
  Set<int> _joinedClubs = {}; // ✅ 이미 가입된 동아리 index 저장

  bool _isSearching = false;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchClubs();
  }
Future<void> fetchClubs() async {
  final snapshot = await _clubRef.get();
  final userProfile = await getUserProfile();
  final String myStudentId = userProfile['studentId'] ?? '';

  List<Map<String, dynamic>> clubs = [];
  Set<int> joined = {};
  Set<int> requested = {}; // ✅ 신청 중인 동아리 index 저장

  if (snapshot.exists) {
    int idx = 0;
    for (var clubSnapshot in snapshot.children) {
      final infoSnapshot = clubSnapshot.child('info');
      if (infoSnapshot.exists) {
        final clubData = {
          'clubcat': infoSnapshot.child('clubcat').value,
          'clubdesc': infoSnapshot.child('clubdesc').value,
          'clubname': infoSnapshot.child('clubname').value,
          'leaderid': infoSnapshot.child('leaderid').value,
        };
        clubs.add(clubData);

        // ✅ 이미 가입한 동아리인지 확인
        final membersSnapshot = clubSnapshot.child('members');
        if (membersSnapshot.hasChild(myStudentId)) {
          joined.add(idx);
        }

        // ✅ 신청한 동아리인지 확인
        final requestSnapshot = clubSnapshot.child('request');
        if (requestSnapshot.hasChild(myStudentId)) {
          requested.add(idx);
        }
      }
      idx++;
    }
  }

  setState(() {
    _allClubs = clubs;
    _filteredClubs = clubs;
    _joinedClubs = joined;
    _selectedClubs = requested; // ✅ 신청 상태 복원
  });
}

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _filteredClubs = _allClubs;
    });
  }

  void _filterClubs(String query) {
    final filtered = _allClubs.where((club) {
      final name = club['clubname']?.toString().toLowerCase() ?? '';
      return name.contains(query.toLowerCase());
    }).toList();

    setState(() {
      _filteredClubs = filtered;
    });
  }

  void _toggleSelect(int index) {
    if (_joinedClubs.contains(index)) {
      // 이미 가입한 동아리는 동작 안 함
      return;
    }

    setState(() {
      if (_selectedClubs.contains(index)) {
        _cancelMyRequest(index);
        _selectedClubs.remove(index);
        _showSnackBar("신청이 취소되었습니다.");
      } else {
        _selectedClubs.add(index);
        _DBpush(index);
        _showSnackBar("신청이 완료되었습니다!");
      }
    });
  }

  Future<void> _DBpush(int index) async {
    final Map<String, dynamic> userProfile = await getUserProfile();

    final String stuname = userProfile['name'] ?? '정보 없음';
    final String stuid = userProfile['studentId'] ?? '정보 없음';
    final String stumajor = userProfile['major'] ?? '정보 없음';
    final String stugender = userProfile['gender'] ?? '정보 없음';
    final String stubirth = userProfile['birth'] ?? '정보 없음';
    final String stucontact = userProfile['contact'] ?? '정보 없음';

    final dbRef = FirebaseDatabase.instance.ref(
      "Club/${_filteredClubs[index]['clubname']}/request",
    );
    dbRef.child(stuid).set({
      "stuname": stuname,
      "stuid": stuid,
      "stumajor": stumajor,
      "stugender": stugender,
      "stubirth": stubirth,
      "stucontact": stucontact,
    });
  }

  Future<void> _cancelMyRequest(int clubIndex) async {
    try {
      final Map<String, dynamic> userProfile = await getUserProfile();
      final String myStudentId = userProfile['studentId'] ?? '';

      if (myStudentId.isEmpty || myStudentId == '정보 없음') {
        print('오류: 사용자 학번을 찾을 수 없어 신청을 취소할 수 없습니다.');
        return;
      }

      final String clubName = _filteredClubs[clubIndex]['clubname'];

      final dbRef = FirebaseDatabase.instance
          .ref("Club/$clubName/request/$myStudentId");

      await dbRef.remove();

      print("'$clubName' 동아리 가입 신청이 취소되었습니다.");
    } catch (e) {
      print("신청 취소 중 오류 발생: $e");
    }
  }

  void _showDetails(Map<String, dynamic> club) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          club['clubname'] ?? '',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('회장: ${club['leaderid'] ?? ''}', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('설명: ${club['clubdesc'] ?? ''}', style: TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            child: Text('닫기'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: 16)),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.blueAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '동아리 이름 검색',
                  border: InputBorder.none,
                ),
                onChanged: _filterClubs,
              )
            : Text('동아리 목록'),
        actions: [
          _isSearching
              ? IconButton(icon: Icon(Icons.close), onPressed: _stopSearch)
              : IconButton(icon: Icon(Icons.search), onPressed: _startSearch),
        ],
      ),
      body: _filteredClubs.isEmpty
          ? Center(child: Text('동아리가 없습니다.'))
          : ListView.builder(
              padding: EdgeInsets.all(12),
              itemCount: _filteredClubs.length,
              itemBuilder: (context, index) {
                final club = _filteredClubs[index];
                final isSelected = _selectedClubs.contains(index);
                final isJoined = _joinedClubs.contains(index);

                return Card(
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    title: Text(
                      club['clubname'] ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '카테고리: ${club['clubcat'] ?? ''}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isJoined)
                          Text(
                            "이미 부원",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else
                          TextButton(
                            onPressed: () => _toggleSelect(index),
                            child: Text(
                              isSelected ? "지원 취소" : "지원하기",
                              style: TextStyle(
                                color: isSelected ? Colors.red : Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        IconButton(
                          icon: Icon(Icons.search, color: Colors.grey[800]),
                          onPressed: () => _showDetails(club),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
