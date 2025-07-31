import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gss/main.dart';
import 'package:gss/services/DBservice.dart';

class EmailSignUpPage extends StatefulWidget {
  const EmailSignUpPage({super.key});

  @override
  State<EmailSignUpPage> createState() => _EmailSignUpPageState();
}

class _EmailSignUpPageState extends State<EmailSignUpPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController stuidController = TextEditingController();
  final TextEditingController majorController = TextEditingController();
  final TextEditingController genderController = TextEditingController();
  final TextEditingController phoneNumController = TextEditingController();
  final TextEditingController birthController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  int currentStep = 0;

  List<Step> steps() => [
    Step(
      state: currentStep > 0 ? StepState.complete : StepState.indexed,
      title: Text('Account'),
      content: Container(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: '이메일'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호 확인'),
              ),
              // const SizedBox(height: 32),
              // ElevatedButton(
              //   onPressed: registerWithEmailAndPassword,
              //   child: const Text("회원가입"),
              // ),
            ],
          ),
        ),
      ),
      isActive: currentStep >= 0
    ),
    Step(title: Text('User Info'), 
      state: currentStep > 1 ? StepState.complete : StepState.indexed,
      content: Container(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: stuidController,
                decoration: const InputDecoration(labelText: '학번'),
              ),
              TextField(
                controller: nameController,
                keyboardType: TextInputType.name,
                decoration: const InputDecoration(labelText: '이름'),
              ),
              TextField(
                controller: majorController,
                decoration: const InputDecoration(labelText: '학과'),
              ),
              TextField(
                controller: genderController,
                decoration: const InputDecoration(labelText: '성별'),
              ),
              TextField(
                controller: phoneNumController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: '전화번호'),
              ),
              TextField(
                controller: birthController,
                decoration: const InputDecoration(labelText: '생년월일'),
              ),
              // const SizedBox(height: 32),
              // ElevatedButton(
              //   onPressed: registerWithEmailAndPassword,
              //   child: const Text("회원가입"),
              // ),
            ],
          ),
        ),
      ), isActive: currentStep >= 1),
    Step(title: Text('Complete'), 
      state: currentStep > 2 ? StepState.complete : StepState.indexed,
      content: Container(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('Email: ${emailController.text}', style: TextStyle(
                fontSize: 20.0
              ),),
              Text('Student ID: ${stuidController.text}',style: TextStyle(
                fontSize: 20.0
              )),
              Text('Name: ${nameController.text}',style: TextStyle(
                fontSize: 20.0
              )),
              Text('Major: ${majorController.text}',style: TextStyle(
                fontSize: 20.0
              )),
              Text('Gender: ${genderController.text}',style: TextStyle(
                fontSize: 20.0
              )),
              Text('Phone No.: ${phoneNumController.text}',style: TextStyle(
                fontSize: 20.0
              )),
              Text('Birth: ${birthController.text}',style: TextStyle(
                fontSize: 20.0
              )),
            ],
          ),
        ),
      ), isActive: currentStep >= 2),
  ];

  void registerWithEmailAndPassword() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("모든 필드를 입력해주세요.")));
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("비밀번호가 일치하지 않습니다.")));
      return;
    }

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      print("회원가입 성공: ${userCredential.user?.email}");

      // 회원가입 성공 후 홈화면으로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MyApp()),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("회원가입 실패: ${e.message}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (BuildContext ctx) {
        return Scaffold(
          appBar: AppBar(title: const Text("이메일 회원가입")),
          body: Stepper(steps: steps(),
          onStepTapped:(value) => setState(() => currentStep = value),
          currentStep: currentStep,
          type: StepperType.horizontal,
          onStepContinue: () async {
            if(currentStep == 0){
              final email = emailController.text.trim();
              final password = passwordController.text;
              final confirmPassword = confirmPasswordController.text;
        
              if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(const SnackBar(content: Text("모든 필드를 입력해주세요.")));
                return;
              }
        
              if (password != confirmPassword) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(const SnackBar(content: Text("비밀번호가 일치하지 않습니다.")));
                return;
              }
        
              setState(() => currentStep += 1);
            }
            else if(currentStep == 2){
              final email = emailController.text.trim();
              final password = passwordController.text;
              try {
              final userCredential = await FirebaseAuth.instance
                  .createUserWithEmailAndPassword(email: email, password: password);

              DBsvc().DBsignup(stuidController.text, nameController.text, emailController.text, 
                majorController.text,genderController.text, birthController.text, phoneNumController.text);
              print("회원가입 성공: ${userCredential.user?.email}");
              // 회원가입 성공 후 홈화면으로 이동
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MyApp()), 
              );
            } on FirebaseAuthException catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("회원가입 실패: ${e.message}")));
            }
            }
            else{ setState(() => currentStep += 1);}
          },
          onStepCancel: currentStep == 0 ? null : () {
            setState(() =>  currentStep -= 1);
          },
          ),
        );
      }
    );
  }
}
