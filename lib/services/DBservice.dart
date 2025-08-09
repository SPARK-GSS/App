import 'dart:ffi';

import 'package:firebase_database/firebase_database.dart';
import 'package:gss/mainpages/event.dart';
import 'package:gss/model/person.dart';

class DBsvc {
  FirebaseDatabase database = FirebaseDatabase.instance;

  DatabaseReference ref = FirebaseDatabase.instance.ref();

  Future<void> DBwrite() async {
    DatabaseReference ref = FirebaseDatabase.instance.ref("Person/person1");

    await ref.set({
      "school": "SKKU",
      "studentId": "2021311210",
      "contact": "010-9719-9725",
      "email": "bjbj2580@g.skku.edu",
      "clubs": {"club1": "KUSA"},
    });
  }

  Future<void> DBsignup(
    String stuid,
    String name,
    String email,
    String major,
    String gender,
    String birth,
    String phone,
  ) async {
    DatabaseReference ref = FirebaseDatabase.instance.ref("Person/$stuid");
    await ref.set({
      "school": "SKKU",
      "name": name,
      "studentId": stuid,
      "contact": phone,
      "email": email,
      "major": major,
      "gender": gender,
      "birth": birth,
      "clubs": {},
    });
  }

  void DBread() {
    DatabaseReference starCountRef = FirebaseDatabase.instance.ref('Person');
    starCountRef.onValue.listen((DatabaseEvent event) {
      //list
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      if (data.isEmpty) {
        print('no data');
        return;
      }

      final people = <Person>[];

      for (final key in data.keys) {
        final user = data[key];
        final person = Person.fromMap(user);
        print(person);
        people.add(person);
      }
      // updateStarCount(data);
    });
  }

  Future<List<Event>> loadEvents(String club, String date) async {
    final ref = FirebaseDatabase.instance.ref("Club/$club/calendar/$date");
    final snapshot = await ref.get();

    if (!snapshot.exists) return [];

    final value = snapshot.value;

    if (value is Map) {
      return value.entries.map((e) {
        if (e.value is Map) {
          // Map일 경우
          final data = e.value as Map;
          return Event(data['title']?.toString() ?? '');
        } else {
          // 그냥 String일 경우
          return Event(e.value.toString());
        }
      }).toList();
    } else if (value is List) {
      return value.where((e) => e != null).map((e) {
        if (e is Map) {
          return Event(e['title']?.toString() ?? '');
        } else {
          return Event(e.toString());
        }
      }).toList();
    } else {
      // value가 String일 때
      return [Event(value.toString())];
    }
  }

  Future<void> DBcalendar(DateTime day, String club, String msg) async {
    String formattedDate =
        "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
    final ref = FirebaseDatabase.instance.ref(
      "Club/$club/calendar/$formattedDate",
    );

    final snapshot = await ref.get();

    List<dynamic> scheduleList = [];

    if (snapshot.exists) {
      // 이미 일정이 존재하면 리스트로 변환
      final data = snapshot.value;
      if (data is List) {
        scheduleList = List.from(data);
      }
    }

    // 새 일정 추가
    scheduleList.add(msg);

    // 리스트로 다시 저장
    await ref.set(scheduleList);
  }

  void DBupdate() {
    final personData = {'school': 'snu'};

    final personSRef = FirebaseDatabase.instance.ref().child('Person/person1');

    personSRef
        .update(personData)
        .then((_) {
          print('success'); // Data saved successfully!
        })
        .catchError((error) {
          print('failed'); // The write failed...
        });
  }

  void DBdelete() {
    final personSRef = FirebaseDatabase.instance.ref().child('Person/person1');
    personSRef.remove();
  }
}
