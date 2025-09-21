import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:gss/services/AuthService.dart';

class JoinRequestPage extends StatefulWidget {
  final String clubName;
  final String token;
  const JoinRequestPage({super.key, required this.clubName, required this.token});

  @override
  State<JoinRequestPage> createState() => _JoinRequestPageState();
}

class _JoinRequestPageState extends State<JoinRequestPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _clubInfo;

  @override
  void initState() {
    super.initState();
    _validateToken();
  }

  Future<void> _validateToken() async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref('Club/${widget.clubName}/invites/${widget.token}')
          .get();
      if (!snap.exists) {
        setState(() {
          _error = '유효하지 않은 초대 링크입니다.';
          _loading = false;
        });
        return;
      }
      final m = Map<dynamic, dynamic>.from(snap.value as Map);
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiresAt = (m['expiresAt'] ?? 0) as int;
      final used = (m['used'] ?? false) == true;
      if (now > expiresAt) {
        setState(() {
          _error = '초대 링크가 만료되었습니다.';
          _loading = false;
        });
        return;
      }
      if (used) {
        // 여러 명이 써도 되게 하려면 이 체크 제거
        setState(() {
          _error = '이미 사용된 초대 링크입니다.';
          _loading = false;
        });
        return;
      }

      final info = await FirebaseDatabase.instance
          .ref('Club/${widget.clubName}/info')
          .get();
      _clubInfo = info.exists ? Map<String, dynamic>.from(info.value as Map) : null;
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = '오류: $e';
        _loading = false;
      });
    }
  }

  Future<void> _sendJoinRequest() async {
    try {
      final sid = await user_stuid();
      final name = await user_name();
      final email = user_email();
      final now = DateTime.now().millisecondsSinceEpoch;

      if (sid == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
        return;
      }

      // 가입 신청 생성
      final reqRef = FirebaseDatabase.instance
          .ref('Club/${widget.clubName}/joinRequests/$sid');
      await reqRef.set({
        'studentId': sid,
        'name': name ?? '',
        'email': email ?? '',
        'requestedAt': now,
        'status': 'pending',
      });

      // 토큰 1회용 처리 (여러 명 사용 가능하게 하려면 주석)
      await FirebaseDatabase.instance
          .ref('Club/${widget.clubName}/invites/${widget.token}/used')
          .set(true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가입 신청이 완료되었습니다. 운영진 승인을 기다려주세요.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('신청 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _clubInfo?['clubname']?.toString() ?? widget.clubName;

    return Scaffold(
      appBar: AppBar(title: const Text('동아리 가입 신청')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? Center(child: Text(_error!))
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"$title" 에 가입하시겠습니까?',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(_clubInfo?['clubdesc']?.toString() ?? '설명 없음',
                style: const TextStyle(color: Colors.grey)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sendJoinRequest,
                icon: const Icon(Icons.how_to_reg),
                label: const Text('가입 신청'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
