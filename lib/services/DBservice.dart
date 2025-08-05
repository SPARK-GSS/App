import 'package:firebase_database/firebase_database.dart';
import 'package:gss/model/person.dart';

class DBsvc{
    FirebaseDatabase database = FirebaseDatabase.instance;

    DatabaseReference ref = FirebaseDatabase.instance.ref();

    
    Future<void> DBwrite() async {
        DatabaseReference ref = FirebaseDatabase.instance.ref("Person/person1");

        await ref.set({
        "school": "SKKU",
        "studentId": "2021311210",
        "contact": "010-9719-9725",
        "email": "bjbj2580@g.skku.edu",
        "clubs": {
            "club1": "KUSA"
        }
        });
    }

    Future<void> DBsignup(String stuid, String name, String email, String major, String gender, String birth, String phone) async {
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
        "clubs": {
        }
        });
    }

    void DBread(){
        DatabaseReference starCountRef =
        FirebaseDatabase.instance.ref('Person'); 
        starCountRef.onValue.listen((DatabaseEvent event) {   //list
            final data = event.snapshot.value as Map<dynamic,dynamic>;
            if(data.isEmpty){
                print('no data');
                return;
            }

            final people = <Person>[];

            for(final key in data.keys){
                final user = data[key];
                final person = Person.fromMap(user);
                print(person);
                people.add(person);
            }
            // updateStarCount(data);
        });
    }


    void DBupdate(){
      final personData = {
        'school' : 'snu',
      };

      final personSRef =
        FirebaseDatabase.instance.ref().child('Person/person1');

      personSRef.update(personData).then((_) {
        print('success');// Data saved successfully!
    })
    .catchError((error) {
        print('failed');// The write failed...
    });
    }

    void DBdelete(){
      final personSRef =
        FirebaseDatabase.instance.ref().child('Person/person1');
      personSRef.remove();
    }
}

