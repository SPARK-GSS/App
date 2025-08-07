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