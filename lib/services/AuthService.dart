import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

String? user_email(){
    final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print(user.email);
      }
    return user!.email;
  }

  
Future<String> user_name() async {
  String? userEmail = user_email();
  final userSnap = await FirebaseDatabase.instance
        .ref('Person')
        .orderByChild('email')
        .equalTo(userEmail)
        .get();

  if (!userSnap.exists) return "nth"; 
  //throw Exception('사용자 정보 없음');

  final userData = (userSnap.value as Map).entries.first;
  final studentId = userData.key; 
  // 동아리 목록 읽기
  final nameSnap = await FirebaseDatabase.instance
      .ref('Person/$studentId/name')
      .get();
  final name = nameSnap.value as String;
  return name;
}

Future<String> user_stuid() async {
  String? userEmail = user_email();
  final userSnap = await FirebaseDatabase.instance
        .ref('Person')
        .orderByChild('email')
        .equalTo(userEmail)
        .get();

  if (!userSnap.exists) throw Exception('사용자 정보 없음');

  final userData = (userSnap.value as Map).entries.first;
  final studentId = userData.key; 
  // 동아리 목록 읽기
  return studentId;
}

Future<String> user_major() async {
  String? userEmail = user_email();
  if (userEmail == null) {
    throw Exception('로그인된 사용자 이메일 정보 없음');
  }

  final userSnap = await FirebaseDatabase.instance
      .ref('Person')
      .orderByChild('email')
      .equalTo(userEmail)
      .get();

  if (!userSnap.exists) {
    throw Exception('해당 이메일을 가진 사용자 정보 없음');
  }

  // userSnap.value는 {"2000111000": {"major": "cse", ...}} 와 같은 Map 형태입니다.
  // 이 Map에서 첫 번째 엔트리의 값(value)을 가져옵니다.
  final userData = (userSnap.value as Map).entries.first.value;

  // userData는 {"major": "cse", "name": "Lee", ...} 형태의 Map이 됩니다.
  // 이 Map에서 'major' 키로 값을 찾습니다.
  final String major = userData['major'] as String;

  return major;
}
Future<Map<String, dynamic>> getUserProfile() async {
  // 1. 현재 사용자의 이메일을 가져옵니다.
  String? userEmail = user_email();
  if (userEmail == null) {
    throw Exception('로그인된 사용자 이메일 정보가 없습니다.');
  }

  // 2. 이메일을 기준으로 Person 테이블에서 사용자 정보를 쿼리합니다.
  final userSnap = await FirebaseDatabase.instance
      .ref('Person')
      .orderByChild('email')
      .equalTo(userEmail)
      .get();

  // 3. 쿼리 결과가 존재하는지 확인합니다.
  if (!userSnap.exists) {
    throw Exception('해당 이메일을 가진 사용자 정보가 DB에 없습니다.');
  }

  // 4. 쿼리 결과에서 사용자 데이터를 추출합니다.
  // userSnap.value는 {"학번": {"이름": "...", "학과": "..."}} 형태의 Map 입니다.
  // .entries.first.value를 통해 내부의 상세 정보 Map을 가져옵니다.
  final userData = (userSnap.value as Map).entries.first.value;

  // 5. 타입 안정성을 위해 Map<String, dynamic>으로 변환하여 반환합니다.
  return Map<String, dynamic>.from(userData);
}

Future<String> user_status(String clubName) async {
  final userSnap = await FirebaseDatabase.instance
      .ref('Club/$clubName/officer')
      .get();
  if(userSnap.value is String) return "You are a memeber."; 
  if(userSnap.value == null) return "You are a memeber."; 
  final officerData = (userSnap.value as Map);
  final isOfficer = officerData.containsValue(await user_stuid());
  if(isOfficer){
    return "You are an officer.";
  }
  else{
    return "You are a memeber."; 
  }
}


class OfficerService {
  /// 현재 사용자 학번
  static Future<String?> currentStudentId() async {
    try {
      return await user_stuid(); // 이미 구현되어 있다고 하셨음
    } catch (_) {
      return null;
    }
  }

  /// officer role: 'president' | 'vice' | 'manager' | 'none'
  static Future<String> roleOf(String clubName) async {
    final sid = await currentStudentId();
    if (sid == null) return 'none';

    final snap = await FirebaseDatabase.instance
        .ref('Club/$clubName/officer')
        .get();

    if (!snap.exists) return 'none';

    final data = Map<dynamic, dynamic>.from(snap.value as Map);

    // 1) president/vice 직속 키 매칭
    final president = data['president']?.toString();
    if (president == sid) return 'president';

    final vice = data['vice']?.toString();
    if (vice == sid) return 'vice';

    // 2) manager 패턴 (manager1, manager2, ...), 또는 managers 맵 지원
    // (1) managerN 키들
    for (final e in data.entries) {
      final k = e.key.toString();
      if (k.startsWith('manager') && e.value?.toString() == sid) {
        return 'manager';
      }
    }
    // (2) managers: { "sid": true, ... } 형태도 지원
    if (data['managers'] is Map) {
      final managers = Map<dynamic, dynamic>.from(data['managers']);
      if (managers.containsKey(sid) && managers[sid] == true) return 'manager';
    }

    return 'none';
  }

  static Future<bool> canManage(String clubName) async {
    final r = await roleOf(clubName);
    return r == 'president' || r == 'vice' || r == 'manager';
  }
  static Future<String> printingRole(String clubName) async {
    final r = await roleOf(clubName);
    if(r == 'president') return "회장";
    else if(r == 'vice') return "부회장";
    else if(r == 'manager') return "운영진";
    else return "부원";
  }
}