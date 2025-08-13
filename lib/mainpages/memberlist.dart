import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:gss/services/AuthService.dart';

/// =======================
/// 권한/역할 유틸 (studentId 기반)
/// =======================
class ListAuth {
  static DatabaseReference officerRef(String club) =>
      FirebaseDatabase.instance.ref('Club/$club/officer');

  /// 현재 로그인 사용자의 학번
  static Future<String?> currentStudentId() async {
    try {
      return await user_stuid(); // AuthService에 이미 구현
    } catch (_) {
      return null;
    }
  }

  /// 특정 학번의 역할 조회: 'president' | 'vice' | 'manager' | 'none'
  static Future<String> roleOf(String club, String sid) async {
    final snap = await officerRef(club).get();
    if (!snap.exists) return 'none';
    final data = Map<dynamic, dynamic>.from(snap.value as Map);

    final president = data['president']?.toString();
    if (president == sid) return 'president';

    final vice = data['vice']?.toString();
    if (vice == sid) return 'vice';

    // managers 맵 지원
    if (data['managers'] is Map) {
      final managers = Map<dynamic, dynamic>.from(data['managers']);
      if (managers.containsKey(sid) && managers[sid] == true) return 'manager';
    }
    // manager1 / manager2 ... 키도 지원
    for (final e in data.entries) {
      final k = e.key.toString();
      if (k.startsWith('manager') && e.value?.toString() == sid) {
        return 'manager';
      }
    }
    return 'none';
  }

  /// 내 역할
  static Future<String> roleOfMe(String club) async {
    final sid = await currentStudentId();
    if (sid == null) return 'none';
    return roleOf(club, sid);
  }

  /// 회장 위임: president <- targetSid, 기존 회장은 managers로
  static Future<void> delegatePresident({
    required String club,
    required String targetSid,
  }) async {
    final mySid = await currentStudentId();
    if (mySid == null) throw Exception('학번 정보를 찾을 수 없습니다.');
    final ref = officerRef(club);
    final updates = <String, dynamic>{
      'president': targetSid,
      'managers/$mySid': true,
      'managers/$targetSid': null, // 타겟이 기존 managers였다면 제거
    };
    await ref.update(updates);
  }

  /// 부회장 위임: vice <- targetSid, 기존 부회장은 managers로
  static Future<void> delegateVice({
    required String club,
    required String targetSid,
  }) async {
    final mySid = await currentStudentId();
    if (mySid == null) throw Exception('학번 정보를 찾을 수 없습니다.');
    final ref = officerRef(club);
    final updates = <String, dynamic>{
      'vice': targetSid,
      'managers/$mySid': true,
      'managers/$targetSid': null,
    };
    await ref.update(updates);
  }

  /// 운영진 임명/해임
  static Future<void> setManager({
    required String club,
    required String targetSid,
    required bool value,
  }) async {
    final ref = officerRef(club).child('managers/$targetSid');
    if (value) {
      await ref.set(true);
    } else {
      await ref.remove();
    }
  }
}

/// =======================
/// MemberList 페이지
/// =======================
class MemberList extends StatefulWidget {
  final String clubName;
  const MemberList({super.key, required this.clubName});

  @override
  State<MemberList> createState() => _MemberListState();
}

class _MemberListState extends State<MemberList> {
  bool _loading = true;
  String _myRole = 'none';

  // memberId list (studentIds)
  List<String> _memberSids = [];
  // sid -> person data
  final Map<String, Map<String, dynamic>> _personBySid = {};
  // sid -> role
  final Map<String, String> _roleBySid = {};

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    try {
      // 내 역할만 확인해서 버튼 노출 제어에 사용
      _myRole = await ListAuth.roleOfMe(widget.clubName);

      // 멤버 목록: Club/{club}/members/{sid}: true
      final membersSnap = await FirebaseDatabase.instance
          .ref('Club/${widget.clubName}/members')
          .get();

      final sids = <String>[];
      if (membersSnap.exists) {
        final m = Map<dynamic, dynamic>.from(membersSnap.value as Map);
        for (final e in m.entries) {
          sids.add(e.key.toString());
        }
      }

      // 각 sid의 Person 데이터와 역할 로드
      for (final sid in sids) {
        final pSnap = await FirebaseDatabase.instance.ref('Person/$sid').get();
        if (pSnap.exists) {
          _personBySid[sid] =
          Map<String, dynamic>.from(pSnap.value as Map<dynamic, dynamic>);
        } else {
          _personBySid[sid] = {
            'name': '(미등록)',
            'studentId': sid,
            'major': '-',
            'contact': '-',
          };
        }
        _roleBySid[sid] = await ListAuth.roleOf(widget.clubName, sid);
      }

      setState(() {
        _memberSids = sids;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'president':
        return '회장';
      case 'vice':
        return '부회장';
      case 'manager':
        return '운영진';
      default:
        return '부원';
    }
  }

  Future<void> _appointManager(String sid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('운영진 임명'),
        content: Text('학번 $sid 을(를) 운영진으로 임명하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('확인')),
        ],
      ),
    );
    if (ok != true) return;

    await ListAuth.setManager(
      club: widget.clubName,
      targetSid: sid,
      value: true,
    );
    _roleBySid[sid] = 'manager';
    if (mounted) setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('운영진으로 임명되었습니다.')));
  }

  Future<void> _revokeManager(String sid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('운영진 해임'),
        content: Text('학번 $sid 의 운영진 권한을 해임하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('확인')),
        ],
      ),
    );
    if (ok != true) return;

    await ListAuth.setManager(
      club: widget.clubName,
      targetSid: sid,
      value: false,
    );
    _roleBySid[sid] = 'none';
    if (mounted) setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('운영진에서 해임되었습니다.')));
  }

  Future<void> _delegatePresident(String sid) async {
    final mySid = await ListAuth.currentStudentId();
    if (mySid == sid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('본인에게는 위임할 수 없습니다.')));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('회장 위임'),
        content: Text('학번 $sid 에게 회장 직책을 위임하시겠습니까?\n(현재 사용자는 운영진으로 변경됩니다)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('확인')),
        ],
      ),
    );
    if (ok != true) return;

    await ListAuth.delegatePresident(club: widget.clubName, targetSid: sid);
    _roleBySid.updateAll((key, value) => key == sid ? 'president' : value);
    if (mySid != null) _roleBySid[mySid] = 'manager';
    if (mounted) setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('회장 위임이 완료되었습니다.')));
  }

  Future<void> _delegateVice(String sid) async {
    final mySid = await ListAuth.currentStudentId();
    if (mySid == sid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('본인에게는 위임할 수 없습니다.')));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('부회장 위임'),
        content: Text('학번 $sid 에게 부회장 직책을 위임하시겠습니까?\n(현재 사용자는 운영진으로 변경됩니다)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('확인')),
        ],
      ),
    );
    if (ok != true) return;

    await ListAuth.delegateVice(club: widget.clubName, targetSid: sid);
    _roleBySid.updateAll((key, value) => key == sid ? 'vice' : value);
    if (mySid != null) _roleBySid[mySid] = 'manager';
    if (mounted) setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('부회장 위임이 완료되었습니다.')));
  }

  List<Widget> _buildActionsFor(String targetSid, String targetRole) {
    final actions = <Widget>[];

    final canAppoint = _myRole == 'president' || _myRole == 'vice';
    final isTop = targetRole == 'president' || targetRole == 'vice';

    // 운영진 임명/해임
    if (canAppoint && !isTop) {
      if (targetRole == 'none') {
        actions.add(
          TextButton.icon(
            onPressed: () => _appointManager(targetSid),
            icon: const Icon(Icons.admin_panel_settings),
            label: const Text('운영진 임명'),
          ),
        );
      } else if (targetRole == 'manager') {
        actions.add(
          TextButton.icon(
            onPressed: () => _revokeManager(targetSid),
            icon: const Icon(Icons.shield),
            label: const Text('운영진 해임'),
          ),
        );
      }
    }

    // 위임 (본인 자리만 가능)
    if (_myRole == 'president' && targetRole != 'president') {
      actions.add(
        TextButton.icon(
          onPressed: () => _delegatePresident(targetSid),
          icon: const Icon(Icons.workspace_premium),
          label: const Text('회장 위임'),
        ),
      );
    }
    if (_myRole == 'vice' && targetRole != 'vice') {
      actions.add(
        TextButton.icon(
          onPressed: () => _delegateVice(targetSid),
          icon: const Icon(Icons.military_tech),
          label: const Text('부회장 위임'),
        ),
      );
    }

    return actions;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('부원 명단')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ✅ 권한 차단 화면 없음 — 탭에서 이미 필터됨
    return Scaffold(
      appBar: AppBar(title: const Text('부원 명단')),
      body: _memberSids.isEmpty
          ? const Center(child: Text('등록된 부원이 없습니다.'))
          : ListView.separated(
        itemCount: _memberSids.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final sid = _memberSids[i];
          final p = _personBySid[sid] ?? {};
          final name = (p['name'] ?? '').toString();
          final major = (p['major'] ?? '').toString();
          final contact = (p['contact'] ?? '').toString();
          final role = _roleBySid[sid] ?? 'none';

          return ListTile(
            title: Text('$name ($sid)'),
            subtitle: Text('학과: $major   전화: $contact'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(
                  label: Text(_roleLabel(role)),
                  backgroundColor: switch (role) {
                    'president' => Colors.orange.shade100,
                    'vice' => Colors.blue.shade100,
                    'manager' => Colors.green.shade100,
                    _ => Colors.grey.shade200,
                  },
                ),
                const SizedBox(width: 8),
                ..._buildActionsFor(sid, role),
              ],
            ),
          );
        },
      ),
    );
  }
}
