import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:gss/main.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: (){
                    signInWithGoogle(context);  //실제로 tap하면 로그인되도록 
                  },
                  child: Card(
                    margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7)),
                      elevation: 2,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/google.jpg'),
                          const SizedBox(
                            width: 10,
                          ),
                          const Text("Sign in with google account",
                          style: TextStyle(color: Colors.grey, fontSize: 17))
                        ],
                      ),
                    
                  ),
                )
              ],)
          )
        ],))
    );
  }
}



void signInWithGoogle(BuildContext context) async {
  final GoogleSignIn signIn = GoogleSignIn.instance;
  await signIn.initialize(
    serverClientId: '1029552906373-3vn65d5rrivk02dpiv5c4itq1pnpgp31.apps.googleusercontent.com'
  );
  // Trigger the authentication flow
  final GoogleSignInAccount googleUser = await signIn.authenticate();
  if(googleUser == null){
    throw FirebaseAuthException(code: "Signin aborted by user", message: 'Signin aborted by user');
  }

  final idToken = googleUser.authentication.idToken;
  final authClient = googleUser.authorizationClient;

  GoogleSignInClientAuthorization? auth = await authClient.authorizationForScopes(['email', 'profile']);

  final accesstoken = auth?.accessToken;

  final credential = GoogleAuthProvider.credential(accessToken: accesstoken, idToken: idToken);

  // Once signed in, return the UserCredential
  return await FirebaseAuth.instance.signInWithCredential(credential).then((value) {
    print(value.user?.email);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => MyApp()));
  }).onError((error, stackTrace){
    print("error $error");

  });

}