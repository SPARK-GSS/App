import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:gss/services/AuthService.dart';

class ClubListPage extends StatefulWidget {
  const ClubListPage({super.key});
  @override
  State<ClubListPage> createState() => _ClubListPageState();
}

class _ClubListPageState extends State<ClubListPage> {
  final DatabaseReference _clubRef = FirebaseDatabase.instance.ref('Club');
  StreamSubscription<DatabaseEvent>? _sub;

  List<Map<String, dynamic>> _allClubs = [];
  List<Map<String, dynamic>> _filteredClubs = [];
  Set<String> _joinedClubKeys = {};
  Set<String> _requestedClubKeys = {};

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sub = _clubRef.onValue.listen((event) async {
      await _refreshFromSnapshot(event.snapshot);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshFromSnapshot(DataSnapshot snapshot) async {
    final userProfile = await getUserProfile();
    final String myStudentId = (userProfile['studentId'] ?? '').toString();

    final List<Map<String, dynamic>> clubs = [];
    final Set<String> joined = {};
    final Set<String> requested = {};

    for (final clubSnap in snapshot.children) {
      final info = clubSnap.child('info');
      if (!info.exists) continue;

      final String key = clubSnap.key ?? '';
      final club = <String, dynamic>{
        'key': key,
        'clubcat': info.child('clubcat').value,
        'clubdesc': info.child('clubdesc').value,
        'clubname': info.child('clubname').value,
        'leaderid': info.child('leaderid').value,
      };
      clubs.add(club);

      if (myStudentId.isNotEmpty) {
        if (clubSnap.child('members').hasChild(myStudentId)) joined.add(key);
        if (clubSnap.child('request').hasChild(myStudentId)) requested.add(key);
      }
    }


    final q = _searchController.text.trim().toLowerCase();


    List<Map<String, dynamic>> filtered = clubs.where((c) {
      final key = c['key']?.toString() ?? '';
      if (joined.contains(key)) return false; // 가입한 클럽 숨김
      if (q.isEmpty) return true;
      final name = c['clubname']?.toString().toLowerCase() ?? '';
      return name.contains(q);
    }).toList();

    if (!mounted) return;
    setState(() {
      _allClubs = clubs;
      _filteredClubs = filtered;
      _joinedClubKeys = joined;
      _requestedClubKeys = requested;
    });
  }

  void _startSearch() => setState(() => _isSearching = true);

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();

      _filteredClubs = _allClubs
          .where((c) => !_joinedClubKeys.contains(c['key']?.toString() ?? ''))
          .toList();
    });
  }

  void _filterClubs(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filteredClubs = _allClubs.where((c) {
        final key = c['key']?.toString() ?? '';
        if (_joinedClubKeys.contains(key)) return false;
        if (q.isEmpty) return true;
        final name = c['clubname']?.toString().toLowerCase() ?? '';
        return name.contains(q);
      }).toList();
    });
  }

  void _toggleSelect(int index) {
    final club = _filteredClubs[index];
    final String clubKey = club['key'] as String? ?? '';
    if (clubKey.isEmpty) return;

    setState(() {
      if (_requestedClubKeys.contains(clubKey)) {
        _cancelMyRequest(clubKey);
        _requestedClubKeys.remove(clubKey);
        _showSnackBar("신청이 취소되었습니다.");
      } else {
        _pushRequest(clubKey);
        _requestedClubKeys.add(clubKey);
        _showSnackBar("신청이 완료되었습니다!");
      }
    });
  }

  Future<void> _pushRequest(String clubKey) async {
    final p = await getUserProfile();
    final stuid = (p['studentId'] ?? '정보 없음').toString();

    await FirebaseDatabase.instance
        .ref("Club/$clubKey/request/$stuid")
        .set({
      "stuname": (p['name'] ?? '정보 없음').toString(),
      "stuid": stuid,
      "stumajor": (p['major'] ?? '정보 없음').toString(),
      "stugender": (p['gender'] ?? '정보 없음').toString(),
      "stubirth": (p['birth'] ?? '정보 없음').toString(),
      "stucontact": (p['contact'] ?? '정보 없음').toString(),
      "requestedAt": ServerValue.timestamp,
    });
  }

  Future<void> _cancelMyRequest(String clubKey) async {
    try {
      final p = await getUserProfile();
      final myId = (p['studentId'] ?? '').toString();
      if (myId.isEmpty || myId == '정보 없음') return;
      await FirebaseDatabase.instance
          .ref("Club/$clubKey/request/$myId")
          .remove();
    } catch (e) {
      debugPrint("신청 취소 중 오류: $e");
    }
  }

  void _showDetails(Map<String, dynamic> club) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          club['clubname']?.toString() ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('회장: ${club['leaderid'] ?? ''}',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('설명: ${club['clubdesc'] ?? ''}',
                style: const TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('닫기', style: TextStyle(color: Colors.black)),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.blueAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '동아리 이름 검색',
            border: InputBorder.none,
          ),
          onChanged: _filterClubs,
        )
            : const Text('동아리 목록'),
        actions: [
          _isSearching
              ? IconButton(icon: const Icon(Icons.close), onPressed: _stopSearch)
              : IconButton(icon: const Icon(Icons.search), onPressed: _startSearch),
        ],
      ),
      body: _filteredClubs.isEmpty
          ? const Center(child: Text('동아리가 없습니다.'))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _filteredClubs.length,
        itemBuilder: (context, index) {
          final club = _filteredClubs[index];
          final String clubKey = club['key']?.toString() ?? '';
          final bool isRequested = _requestedClubKeys.contains(clubKey);

          return Card(
            color: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              title: Text(
                club['clubname']?.toString() ?? '',
                style: const TextStyle(
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
                  TextButton(
                    onPressed: () => _toggleSelect(index),
                    child: Text(
                      isRequested ? "신청 취소" : "지원하기",
                      style: TextStyle(
                        color: isRequested
                            ? const Color.fromRGBO(209, 87, 90, 1.0)
                            : const Color.fromRGBO(216, 162, 163, 1.0),
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
