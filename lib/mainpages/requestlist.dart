import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ClubRequestPage extends StatefulWidget {
  final String clubName; // 현재 동아리 이름

  const ClubRequestPage({super.key, required this.clubName});

  @override
  State<ClubRequestPage> createState() => _ClubRequestPageState();
}

class _ClubRequestPageState extends State<ClubRequestPage> {
  final DatabaseReference _clubRef = FirebaseDatabase.instance.ref("Club");
  final DatabaseReference _personRef = FirebaseDatabase.instance.ref("Person");

  List<Map<String, String>> requests = [];

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  Future<void> fetchRequests() async {
    final snapshot = await _clubRef.child(widget.clubName).child("request").get();

    List<Map<String, String>> temp = [];
    if (snapshot.exists) {
      for (var child in snapshot.children) {
        String studentId = child.key ?? "";
        final personSnap = await _personRef.child(studentId).get();
        if (personSnap.exists) {
          final data = personSnap.value as Map;
          temp.add({
            "studentId": studentId,
            "name": data['name'] ?? "이름 없음",
            "department": data['department'] ?? "학과 없음",
            "gender": data['gender'] ?? "성별 없음",
            "birth": data['birth'] ?? "생일 없음",
            "contact": data['contact'] ?? "연락처 없음",
          });
        }
      }
    }

    if (!mounted) return; // ✅ 페이지가 dispose 되었으면 setState 호출하지 않음
    setState(() {
      requests = temp;
    });
  }

  Future<void> approveRequest(String studentId) async {
    final clubName = widget.clubName;

    // members에 추가
    await _clubRef.child(clubName).child("members").child(studentId).set(true);

    // Person/학번/club에 현재 동아리 추가
    final personClubRef = _personRef.child(studentId).child("club");
    final snapshot = await personClubRef.get();
    int nextIndex = snapshot.exists ? snapshot.children.length + 1 : 1;
    await personClubRef.child("club $nextIndex").set(clubName);

    // request에서 삭제
    await _clubRef.child(clubName).child("request").child(studentId).remove();

    if (!mounted) return;
    setState(() {
      requests.removeWhere((r) => r["studentId"] == studentId);
    });
  }

  Future<void> rejectRequest(String studentId) async {
    final clubName = widget.clubName;

    // request에서 삭제
    await _clubRef.child(clubName).child("request").child(studentId).remove();

    if (!mounted) return;
    setState(() {
      requests.removeWhere((r) => r["studentId"] == studentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.clubName} 지원자 목록")),
      body: requests.isEmpty
          ? const Center(child: Text("지원자가 없습니다."))
          : ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final req = requests[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${req["name"]} (${req["studentId"]})",
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text("학과: ${req["department"]}"),
                        Text("성별: ${req["gender"]}"),
                        Text("생일: ${req["birth"]}"),
                        Text("연락처: ${req["contact"]}"),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: () =>
                                  approveRequest(req["studentId"]!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text("승인"),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () =>
                                  rejectRequest(req["studentId"]!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text("거절"),
                            ),
                          ],
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
