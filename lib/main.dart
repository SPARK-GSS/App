import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:gss/pages/splash.dart';
import 'package:gss/homepage.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  await _ensureFirebase();

  runApp(const SplashScreen());
}

Future<FirebaseApp> _ensureFirebase() async {
  try {
    return await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {

    if (e.code == 'duplicate-app') {
      return Firebase.app();
    }
    rethrow;
  }
}
///아오
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      theme: ThemeData(

        fontFamily: "Pretendard",

        // 컬러 스킴 커스텀
        // colorScheme: const ColorScheme.light(
        //   primary: Color.fromRGBO(216, 162, 163, 1.0),
        //   onPrimary: Colors.white,
        //   surface: Colors.white,
        //   onSurface: Colors.black,
        // ),
      ),
      home: homepage(),
    );
  }
}
