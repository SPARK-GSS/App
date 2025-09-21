import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:gss/services/AuthService.dart';

/// =======================
/// 권한/역할 유틸 (studentId 기반)
/// =======================
class ListAuth {
  static DatabaseReference officerRef(String club) =>
      FirebaseDatabase.instance.ref('Club/$club/officer');

  static Future<String?> currentStudentId() async {
    try {
      return await user_stuid(); // AuthService에 구현되어 있다고 가정
    } catch (_) {
      return null;
    }
  }

  /// 'president' | 'vice' | 'manager' | 'none'
  static Future<String> roleOf(String club, String sid) async {
    final snap = await officerRef(club).get();
    if (!snap.exists) return 'none';
    final data = Map<dynamic, dynamic>.from(snap.value as Map);

    final president = data['president']?.toString();
    if (president == sid) return 'president';

    final vice = data['vice']?.toString();
    if (vice == sid) return 'vice';

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
      'managers/$mySid': true, // 본인은 운영진으로
      'managers/$targetSid': null, // 타겟이 managers였다면 제거
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

class _MenuAction {
  final String key; // 'appoint' | 'revoke' | 'delegate_pres' | 'delegate_vice'
  final String label;
  final IconData icon;

  _MenuAction(this.key, this.label, this.icon);
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
  String? _mySid; // 내 학번

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

  Future<void> _openRoleMenu(BuildContext ctx, String sid, String role) async {
    final actions = _menuFor(sid, role);
    if (actions.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('사용 가능한 작업이 없습니다.')),
      );
      return;
    }

    final selectedKey = await showModalBottomSheet<String>(
      context: ctx,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: actions.map((a) {
            return ListTile(
              leading: Icon(a.icon),
              title: Text(a.label),
              onTap: () => Navigator.pop(sheetCtx, a.key),
            );
          }).toList(),
        ),
      ),
    );

    switch (selectedKey) {
      case 'appoint':
        await _appointManager(sid);
        break;
      case 'revoke':
        await _revokeManager(sid);
        break;
      case 'delegate_pres':
        await _delegatePresident(sid);
        break;
      case 'delegate_vice':
        await _delegateVice(sid);
        break;
      default:
        break;
    }
  }


  Future<void> _initLoad() async {
    try {
      _mySid = await ListAuth.currentStudentId();
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
          _personBySid[sid] = Map<String, dynamic>.from(
            pSnap.value as Map<dynamic, dynamic>,
          );
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

  Color _roleColor(String role) {
    switch (role) {
      case 'president':
        return Color.fromRGBO(216, 162, 163, 1.0);
      case 'vice':
        return Color.fromRGBO(201, 162, 216, 1.0);
      case 'manager':
        return Color.fromRGBO(162, 216, 163, 1.0);
      default:
        return Colors.white;
    }
  }

  // ===== 액션 구현 =====
  Future<void> _appointManager(String sid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('운영진 임명'),
        content: Text('학번 $sid 을(를) 운영진으로 임명하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('확인'),
          ),
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
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('운영진으로 임명되었습니다.')));
  }

  Future<void> _revokeManager(String sid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('운영진 해임'),
        content: Text('학번 $sid 의 운영진 권한을 해임하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('확인'),
          ),
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
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('운영진에서 해임되었습니다.')));
  }

  Future<void> _delegatePresident(String sid) async {
    if (_mySid == sid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('본인에게는 위임할 수 없습니다.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('회장 위임'),
        content: Text('학번 $sid 에게 회장 직책을 위임하시겠습니까?\n(현재 사용자는 운영진으로 변경됩니다)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await ListAuth.delegatePresident(club: widget.clubName, targetSid: sid);

    // 테이블 반영
    for (var i = 0; i < _memberSids.length; i++) {
      final s = _memberSids[i];
      if (s == sid) {
        _roleBySid[s] = 'president';
      }
      if (s == _mySid) {
        _roleBySid[s] = 'manager';
      }
    }
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('회장 위임이 완료되었습니다.')));
  }

  Future<void> _delegateVice(String sid) async {
    if (_mySid == sid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('본인에게는 위임할 수 없습니다.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('부회장 위임'),
        content: Text('학번 $sid 에게 부회장 직책을 위임하시겠습니까?\n(현재 사용자는 운영진으로 변경됩니다)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await ListAuth.delegateVice(club: widget.clubName, targetSid: sid);

    for (var i = 0; i < _memberSids.length; i++) {
      final s = _memberSids[i];
      if (s == sid) {
        _roleBySid[s] = 'vice';
      }
      if (s == _mySid) {
        _roleBySid[s] = 'manager';
      }
    }
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('부회장 위임이 완료되었습니다.')));
  }

  /// ===== 미트볼 메뉴 구성 =====

  List<_MenuAction> _menuFor(String targetSid, String targetRole) {
    final canAppoint = _myRole == 'president' || _myRole == 'vice';
    final isTop = targetRole == 'president' || targetRole == 'vice';
    final isSelf = (_mySid != null && targetSid == _mySid);

    final menu = <_MenuAction>[];

    // 운영진 임명/해임 (상위직 대상 제외)
    if (canAppoint && !isTop) {
      if (targetRole == 'none') {
        menu.add(_MenuAction('appoint', '운영진 임명', Icons.admin_panel_settings));
      } else if (targetRole == 'manager') {
        menu.add(_MenuAction('revoke', '운영진 해임', Icons.shield));
      }
    }

    // 회장/부회장 위임 (본인에게 위임 불가)
    if (_myRole == 'president' && targetRole != 'president' && !isSelf) {
      menu.add(_MenuAction('delegate_pres', '회장 위임', Icons.workspace_premium));
    }
    if (_myRole == 'vice' && targetRole != 'vice' && !isSelf) {
      menu.add(_MenuAction('delegate_vice', '부회장 위임', Icons.military_tech));
    }

    return menu;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
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
                  trailing: Builder(
                    builder: (context) {
                      final role = _roleBySid[sid] ?? 'none';
                      return ActionChip(
                        label: Text(_roleLabel(role)),
                        onPressed: () => _openRoleMenu(context, sid, role),
                        // Flutter M3에서는 WidgetStateProperty로 감싸줘야 에러 안 남
                        backgroundColor: _roleColor(role),
                        // 선택/비활성 등 상태별로 바꾸고 싶으면 resolveWith 사용
                        // backgroundColor: WidgetStateProperty.resolveWith((states) { ... })
                      );
                    },
                  ),

                );
              },
            ),
    );
  }
}
