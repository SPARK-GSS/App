import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:gss/main.dart';
import 'package:gss/pages/no_google_sign_up.dart';
import 'package:gss/services/AuthService.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
            backgroundColor: Colors.white
          //title: Center(child: Text('GSS')),
          // bottom: TabBar(
          //   tabs: [
          //     Tab(text: 'Log in', icon: Icon(Icons.login)),
          //     Tab(text: 'Sign up', icon: Icon(Icons.new_label)),
          //   ],
          // ),
        ),
        body: Column(
          children: [
            SizedBox(height: 100),
            //Center(child: Text('GSS')),
            Center(
              child: Text(
                'Welcome to GSS!',
                style: TextStyle(
                  fontSize: 30,
                  color: Color.fromRGBO(0, 0, 0, 1.0),
                  fontFamily: "Pretendard",
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(height: 50),
            LogIn(),
          ],
        ),
        // TabBarView(
        //   children: [
        //     SizedBox.expand(child: LogIn()),
        //     SizedBox.expand(child: SignUp()),
        //   ],
        // ),
      ),
    );
  }
}

class LogIn extends StatefulWidget {
  const LogIn({super.key});

  @override
  State<LogIn> createState() => _LogInState();
}

class _LogInState extends State<LogIn> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool loginTF = false;
  Future<String?> signIn(String email, String pw) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pw,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'channel-error') {
        return "모든 필드를 입력해주세요.";
      } else if (e.code == 'invalid-email') {
        return "이메일의 형식을 지켜주세요.";
      } else if (e.code == 'invalid-email') {
        return "이메일에 해당하는 계정이 존재하지 않습니다";
      } else {
        print("${e.code}");
        return "비밀번호가 일치하지 않습니다.";
      }
    } catch (e, stackTrace) {
      print("Error type: ${e.runtimeType}");
      print("Error details: $e");
      print(stackTrace);
      return "Unknown error occurred.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              margin: EdgeInsets.fromLTRB(25, 0, 25, 0),
              padding: EdgeInsets.fromLTRB(15, 0, 0, 0),
              decoration: BoxDecoration(
                border: Border.all(
                    color: Color.fromRGBO(172, 172, 172, 1.0),
                  width: 1.0
                ),
                borderRadius: BorderRadius.circular(20),
                color: Color.fromRGBO(255, 255, 255, 1.0),
              ),
              child: TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  icon: Icon(Icons.email, color: Color.fromRGBO(
                      172, 172, 172, 1.0)),
                  labelText: 'Email',
                  labelStyle: TextStyle(
                    fontFamily: "Pretendard",
                    fontWeight: FontWeight.w800,
                    color: Color.fromRGBO(172, 172, 172, 1.0),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10),
            Container(
              margin: EdgeInsets.fromLTRB(25, 0, 25, 0),
              padding: EdgeInsets.fromLTRB(15, 0, 0, 0),
              decoration: BoxDecoration(
                border: Border.all(
                    color: Color.fromRGBO(172, 172, 172, 1.0),
                    width: 1.0
                ),
                borderRadius: BorderRadius.circular(20),
                color: Color.fromRGBO(255, 255, 255, 1.0),
              ),
              child: TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  icon: Icon(Icons.password, color: Color.fromRGBO(
        172, 172, 172, 1.0)),
                  labelText: 'Password',
                  labelStyle: TextStyle(
                    color: Color.fromRGBO(172, 172, 172, 1.0),
                    fontFamily: "Pretendard",
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(

                backgroundColor: Color.fromRGBO(216, 162, 163, 1.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)
                )
        ),
              onPressed: () async {
                final errMsg = await signIn(
                  emailController.text,
                  passwordController.text,
                );

                if (errMsg == null) {
                  // 로그인 성공
                  if (!mounted) return;
                  Navigator.pushReplacement(
                    ctx,
                    MaterialPageRoute(builder: (context) => const MyApp()),
                  );
                } else {
                  // 로그인 실패
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(SnackBar(content: Text(errMsg)));
                }
              },
              child: const Text(
                "Sign In!",
                style: TextStyle(
                  fontFamily: "Pretendard",
                  fontWeight: FontWeight.w800,
                  color: Color.fromRGBO(119, 119, 119, 1.0),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account?",
                  style: TextStyle(
                    fontFamily: "Pretendard",
                    fontWeight: FontWeight.w800,
                    color: Color.fromRGBO(119, 119, 119, 1.0)
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmailSignUpPage(),
                      ),
                    );
                  },
                  child: Text(
                    "Register Now",
                    style: TextStyle(
                      fontFamily: "Pretendard",
                      fontWeight: FontWeight.w800,
                      color: Color.fromRGBO(0,0,0,1.0),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: Color.fromRGBO(0,0,0,1.0),
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    "or",
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: "Pretendard",
                      fontWeight: FontWeight.w800,
                      color: Color.fromRGBO(0,0,0,1.0),
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: Color.fromRGBO(0,0,0,1.0),
                    thickness: 1,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Center(
              child: Text(
                "Sign in with",
                style: TextStyle(
                  fontFamily: "Pretendard",
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    signInWithGoogle(context);
                  },
                  icon: SizedBox(
                    height: 50,
                    width: 50,
                    child: Image.asset('assets/google_removebg.png'),
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: SizedBox(
                    height: 50,
                    width: 50,
                    child: Image.asset('assets/apple.png'),
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: SizedBox(
                    height: 50,
                    width: 50,
                    child: Image.asset('assets/kakao.png'),
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: SizedBox(
                    height: 50,
                    width: 50,
                    child: Image.asset('assets/naver.png'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class SignUp extends StatelessWidget {
  const SignUp({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmailSignUpPage(),
                    ),
                  ); //실제로 tap하면 로그인되도록
                },
                child: Card(
                  margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                  elevation: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      //Image.asset('assets/google.jpg'),
                      const SizedBox(width: 10),
                      const Text(
                        "Sign in without google",
                        style: TextStyle(color: Colors.grey, fontSize: 17),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  signInWithGoogle(context); //실제로 tap하면 로그인되도록
                },
                child: Card(
                  margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                  elevation: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        child: Image.asset('assets/google_removebg.png'),
                        height: 50,
                        width: 50,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Sign in with google account",
                        style: TextStyle(color: Colors.grey, fontSize: 17),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void signInWithGoogle(BuildContext context) async {
  final GoogleSignIn signIn = GoogleSignIn.instance;
  await signIn.initialize(
    serverClientId:
        '1029552906373-3vn65d5rrivk02dpiv5c4itq1pnpgp31.apps.googleusercontent.com',
  );
  // Trigger the authentication flow
  final GoogleSignInAccount googleUser = await signIn.authenticate();
  if (googleUser == null) {
    throw FirebaseAuthException(
      code: "Signin aborted by user",
      message: 'Signin aborted by user',
    );
  }

  final idToken = googleUser.authentication.idToken;
  final authClient = googleUser.authorizationClient;

  GoogleSignInClientAuthorization? auth = await authClient
      .authorizationForScopes(['email', 'profile']);

  final accesstoken = auth?.accessToken;

  final credential = GoogleAuthProvider.credential(
    accessToken: accesstoken,
    idToken: idToken,
  );

  // Once signed in, return the UserCredential
  return await FirebaseAuth.instance
      .signInWithCredential(credential)
      .then((value) async {
        print(value.user?.email);
        String name = await user_name();
        if(name=="nth"){
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => GoogleSignUpPage()),
          );
        }
        else{
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (context) => MyApp()));
        }
      })
      .onError((error, stackTrace) {
        print("error $error");
      });
}
