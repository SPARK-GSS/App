import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:gss/pages/splash.dart';
import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuth 임포트
import 'package:flutter/material.dart';
import 'package:gss/homepage.dart';
import 'package:gss/pages/join_request_page.dart';
import 'package:gss/pages/login.dart'; // 사용자의 로그인 페이지 경로 (예시)
import 'package:go_router/go_router.dart';

// --- GoRouter 설정 ---
final GoRouter _router = GoRouter(
  // redirect 콜백 함수 추가
  redirect: (BuildContext context, GoRouterState state) {
    // 현재 Firebase에 로그인된 사용자가 있는지 확인
    final bool loggedIn = FirebaseAuth.instance.currentUser != null;
    // 사용자가 가려는 경로가 '/login'인지 확인
    final bool loggingIn = state.matchedLocation == '/login';

    // 1. 로그인되어 있지 않고, 로그인 페이지로 가는 중이 아니라면
    if (!loggedIn && !loggingIn) {
      // 로그인 페이지로 강제 이동
      return '/login';
    }

    // 2. 로그인되어 있는데, 로그인 페이지로 가려고 한다면
    if (loggedIn && loggingIn) {
      // 홈 페이지로 강제 이동
      return '/';
    }

    // 그 외의 경우는 그대로 진행
    return null;
  },
  routes: <RouteBase>[
    // 기본 경로 (홈)
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return homepage();
      },
    ),
    // 로그인 페이지 경로
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) {
        // 실제 사용하시는 로그인 위젯을 반환해주세요.
        return Login();
      },
    ),
    // 초대 링크 경로
    GoRoute(
      path: '/invite',
      builder: (BuildContext context, GoRouterState state) {
        final clubName = state.uri.queryParameters['club'] ?? '';
        final token = state.uri.queryParameters['token'] ?? '';

        if (clubName.isEmpty || token.isEmpty) {
          return const Scaffold(
            body: Center(child: Text("잘못된 초대 링크입니다.")),
          );
        }

        return JoinRequestPage(clubName: clubName, token: token);
      },
    ),
  ],
);

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
