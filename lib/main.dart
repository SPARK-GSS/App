import 'package:flutter/material.dart';
import 'package:gss/homepage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gss/pages/splash.dart';
import 'firebase_options.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      name: "gss",
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(const MyApp());
  //SplashScreen
}


class MyApp extends StatelessWidget {

  const MyApp({super.key});

  // This widget is the root of your application.
  @override 
  Widget build(BuildContext context) {
    return MaterialApp(
        home: homepage(),
    );
  }
}