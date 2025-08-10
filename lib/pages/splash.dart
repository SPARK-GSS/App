import 'package:flutter/material.dart';
import 'package:gss/main.dart';
import 'package:gss/pages/login.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
bool _isLogin = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Scaffold(backgroundColor: Colors.white, body:_isLogin ? MyApp() : Login() ));
  }
}