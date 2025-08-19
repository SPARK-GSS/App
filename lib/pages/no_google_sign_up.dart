import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:gss/main.dart';
import 'package:gss/mainpages/timepicker.dart';
import 'package:gss/services/AuthService.dart';
import 'package:gss/services/DBservice.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

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
  String gender = '남';

  // ✅ Stepper 밖에서 한 번만 선언
  final _formKey = GlobalKey<FormState>();
  bool isAuthed = false;

  DateTime selectedStartDateTime = DateTime.now();
  List<Step> steps() => [
    Step(
      state: currentStep > 0 ? StepState.complete : StepState.indexed,
      title: const Text('Account'),
      content: Form(
        key: _formKey, // ✅ Account 단계 전체를 Form으로 감싸기
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(
                    fontFamily: "Pretendard",
                    fontWeight: FontWeight.w500,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "이메일을 입력해주세요";
                  }
                  // 간단 이메일 정규식
                  String pattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
                  if (!RegExp(pattern).hasMatch(value)) {
                    return "올바른 이메일 형식이 아닙니다";
                  }
                  return null;
                },
                autovalidateMode:
                    AutovalidateMode.onUserInteraction, // 입력 즉시 검사
              ),
              //     IconButton(onPressed: () async {
              //                     final authCredential = EmailAuthProvider
              //     .credentialWithLink(email: emailController.text, emailLink: emailLink.toString());
              // try {
              //     await FirebaseAuth.instance.currentUser
              //         ?.linkWithCredential(authCredential);
              // } catch (error) {
              //     print("Error linking emailLink credential.");
              // }
              //     }, icon: Text("이메일 인증증"))
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(
                    fontFamily: "Pretendard",
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password check',
                  labelStyle: TextStyle(
                    fontFamily: "Pretendard",
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isActive: currentStep >= 0,
    ),
    Step(
      title: Text('User Info'),
      state: currentStep > 1 ? StepState.complete : StepState.indexed,
      content: Container(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: stuidController,
                decoration: const InputDecoration(labelText: '학번'),
                keyboardType: TextInputType.number, // 숫자 키보드 표시
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, // 숫자만 입력 허용
                ],
              ),

              TextField(
                controller: nameController,
                keyboardType: TextInputType.name,
                decoration: const InputDecoration(labelText: '이름'),
              ),
              // TextField(
              //   controller: majorController,
              //   decoration: const InputDecoration(labelText: '학과'),
              // ),
              MajorField(majorController: majorController),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: '남',
                    groupValue: gender,
                    onChanged: (value) {
                      setState(() {
                        gender = value!;
                      });
                    },
                  ),
                  const Text('남'),
                  Radio<String>(
                    value: '여',
                    groupValue: gender,
                    onChanged: (value) {
                      setState(() {
                        gender = value!;
                      });
                    },
                  ),
                  const Text('여'),
                ],
              ),
              // TextField(
              //   controller: phoneNumController,
              //   keyboardType: TextInputType.phone,
              //   decoration: const InputDecoration(labelText: '전화번호'),
              // ),
              PhoneNumberField(phoneNumController: phoneNumController),
              SizedBox(
                height: 150,
                child: Row(
                  children: [
                    const Text('생년월일'),
                    Expanded(
                      // ✅ 여기서 Expanded 사용
                      child: DatePicker(
                        onDateTimeChanged: (DateTime birthDate) {
                          setState(() {
                            selectedStartDateTime = birthDate;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      isActive: currentStep >= 1,
    ),
    Step(
      title: Text('Complete'),
      state: currentStep > 2 ? StepState.complete : StepState.indexed,
      content: Container(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Email: ${emailController.text}',
                style: TextStyle(fontSize: 20.0),
              ),
              Text(
                'Student ID: ${stuidController.text}',
                style: TextStyle(fontSize: 20.0),
              ),
              Text(
                'Name: ${nameController.text}',
                style: TextStyle(fontSize: 20.0),
              ),
              Text(
                'Major: ${majorController.text}',
                style: TextStyle(fontSize: 20.0),
              ),
              Text('Gender: $gender', style: TextStyle(fontSize: 20.0)),
              Text(
                'Phone No.: ${phoneNumController.text}',
                style: TextStyle(fontSize: 20.0),
              ),
              Text(
                'Birth: ${DateFormat('yyyy-MM-dd').format(selectedStartDateTime)}',
                style: TextStyle(fontSize: 20.0),
              ),
            ],
          ),
        ),
      ),
      isActive: currentStep >= 2,
    ),
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
          appBar: AppBar(
            title: const Text(
              "Sign up",
              style: TextStyle(
                fontFamily: "Pretendard",
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          body: Stepper(
            steps: steps(),
            onStepTapped: (value) => setState(() => currentStep = value),
            currentStep: currentStep,
            type: StepperType.horizontal,
            onStepContinue: () async {
              if (currentStep == 0) {
                final email = emailController.text.trim();
                final password = passwordController.text;
                final confirmPassword = confirmPasswordController.text;

                if (!_formKey.currentState!.validate()) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text("이메일 형식이 아닙니다.")),
                  );
                  return;
                }

                if (email.isEmpty ||
                    password.isEmpty ||
                    confirmPassword.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text("모든 필드를 입력해주세요.")),
                  );
                  return;
                }

                if (password != confirmPassword) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text("비밀번호가 일치하지 않습니다.")),
                  );
                  return;
                }

                setState(() => currentStep += 1);
              } else if (currentStep == 2) {
                final email = emailController.text.trim();
                final password = passwordController.text;
                try {
                  final userCredential = await FirebaseAuth.instance
                      .createUserWithEmailAndPassword(
                        email: email,
                        password: password,
                      );

                  DBsvc().DBsignup(
                    stuidController.text,
                    nameController.text,
                    emailController.text,
                    majorController.text,
                    gender,
                    selectedStartDateTime,
                    phoneNumController.text,
                  );
                  print("회원가입 성공: ${userCredential.user?.email}");
                  // 회원가입 성공 후 홈화면으로 이동
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const MyApp()),
                  );
                } on FirebaseAuthException catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("회원가입 실패: ${e.message}")),
                  );
                }
              } else {
                setState(() => currentStep += 1);
              }
            },
            onStepCancel: currentStep == 0
                ? null
                : () {
                    setState(() => currentStep -= 1);
                  },
          ),
        );
      },
    );
  }
}

class GoogleSignUpPage extends StatefulWidget {
  const GoogleSignUpPage({super.key});

  @override
  State<GoogleSignUpPage> createState() => _GoogleSignUpPageState();
}

class _GoogleSignUpPageState extends State<GoogleSignUpPage> {
  @override
  String gender = '남';
  DateTime selectedStartDateTime = DateTime.now();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController stuidController = TextEditingController();
  final TextEditingController majorController = TextEditingController();
  final TextEditingController genderController = TextEditingController();
  final TextEditingController phoneNumController = TextEditingController();
  final TextEditingController birthController = TextEditingController();

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Container(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: stuidController,
                decoration: const InputDecoration(labelText: '학번'),
                keyboardType: TextInputType.number, // 숫자 키보드 표시
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, // 숫자만 입력 허용
                ],
              ),
              TextField(
                controller: nameController,
                keyboardType: TextInputType.name,
                decoration: const InputDecoration(labelText: '이름'),
              ),
              MajorField(majorController: majorController),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: '남',
                    groupValue: gender,
                    onChanged: (value) {
                      setState(() {
                        gender = value!;
                      });
                    },
                  ),
                  const Text('남'),
                  Radio<String>(
                    value: '여',
                    groupValue: gender,
                    onChanged: (value) {
                      setState(() {
                        gender = value!;
                      });
                    },
                  ),
                  const Text('여'),
                ],
              ),

              // TextField(
              //   controller: genderController,
              //   decoration: const InputDecoration(labelText: '성별'),
              // ),
              // TextField(
              //   controller: phoneNumController,
              //   keyboardType: TextInputType.phone,
              //   decoration: const InputDecoration(labelText: '전화번호'),
              // ),
              // TextField(
              //   controller: birthController,
              //   decoration: const InputDecoration(labelText: '생년월일'),
              // ),
              PhoneNumberField(phoneNumController: phoneNumController),
              SizedBox(
                height: 150,
                child: Row(
                  children: [
                    const Text('생년월일'),
                    Expanded(
                      // ✅ 여기서 Expanded 사용
                      child: DatePicker(
                        onDateTimeChanged: (DateTime birthDate) {
                          setState(() {
                            selectedStartDateTime = birthDate;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  DBsvc().DBsignup(
                    stuidController.text,
                    nameController.text,
                    user_email()!,
                    majorController.text,
                    gender,
                    selectedStartDateTime,
                    phoneNumController.text,
                  );
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const MyApp()),
                  );
                },
                child: const Text("회원가입"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MajorField extends StatelessWidget {
  final TextEditingController majorController;

  MajorField({super.key, required this.majorController});

  // 학과 목록 (예: 가나다순 정렬)
  final List<String> majors = [
    "유학.동양학과",
    "국어국문학과",
    "영어영문학과",
    "독어독문학과",
    "러시아어문학과",
    "프랑스어문학과",
    "중어중문학과",
    "한문학과",
    "사학과",
    "철학과",
    "문헌정보학과",
    "행정학과",
    "정치외교학과",
    "미디어커뮤니케이션학과",
    "사회학과",
    "test",
  ];

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        // 입력 없으면 전체 학과 보여주기
        if (textEditingValue.text.isEmpty) {
          return majors;
        }
        // 입력한 글자로 시작하는 학과만 필터링
        return majors.where((major) => major.contains(textEditingValue.text));
      },
      onSelected: (String selection) {
        majorController.text = selection;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(labelText: "학과"),
        );
      },
    );
  }
}

class PhoneNumberField extends StatelessWidget {
  final TextEditingController phoneNumController;

  PhoneNumberField({super.key, required this.phoneNumController});

  // 3-4-4 패턴 지정
  final maskFormatter = MaskTextInputFormatter(
    mask: '###-####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: phoneNumController,
      keyboardType: TextInputType.phone,
      inputFormatters: [maskFormatter],
      decoration: const InputDecoration(labelText: '전화번호'),
    );
  }
}
