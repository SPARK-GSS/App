import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:gss/main.dart';
import 'package:gss/mainpages/timepicker.dart'; // 사용 안 해도 유지 가능
import 'package:gss/services/AuthService.dart';
import 'package:gss/services/DBservice.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';


/// ===============================
/// Local Style (이 파일 전용)
/// ===============================
const kGreyBorder = Color.fromRGBO(172, 172, 172, 1.0); // #ACACAC
const kCursorGrey = Color.fromRGBO(119, 119, 119, 1.0); // #777777
const kBtnPink   = Color.fromRGBO(216, 162, 163, 1.0);  // rgba(216,162,163,1.0)

const kLabelStyle = TextStyle(
  fontFamily: "Pretendard",
  fontWeight: FontWeight.w800,
  color: kGreyBorder,
);

/// 공통 입력 필드 컨테이너 (라운드/보더/패딩)
class _FieldShell extends StatelessWidget {
  final Widget child;
  const _FieldShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      //margin: const EdgeInsets.fromLTRB(25, 0, 25, 0), // 가로 꽉 채우기 위해 제거
      padding: const EdgeInsets.fromLTRB(15, 0, 0, 0),
      decoration: BoxDecoration(
        border: Border.all(color: kGreyBorder, width: 1.0),
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
      ),
      child: child,
    );
  }
}

/// TextFormField 버전 (validator 필요할 때)
class AppTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;

  const AppTextFormField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        cursorColor: kCursorGrey,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: icon != null ? Icon(icon, color: kGreyBorder) : null,
          labelText: label,
          labelStyle: kLabelStyle,
        ),
        style: const TextStyle(fontFamily: "Pretendard"),
        validator: validator,
        autovalidateMode:
        validator != null ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      ),
    );
  }
}

/// TextField 버전 (validator 불필요할 때)
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldShell(
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        cursorColor: kCursorGrey,
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: icon != null ? Icon(icon, color: kGreyBorder) : null,
          labelText: label,
          labelStyle: kLabelStyle,
        ),
        style: const TextStyle(fontFamily: "Pretendard"),
      ),
    );
  }
}



/// 공통 버튼 스타일
ButtonStyle appPrimaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: kBtnPink,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

/// ===============================
/// 가벼운 상태 컨테이너 (컨트롤러/선택값 모음)
/// ===============================
class _SignUpModel {
  final email = TextEditingController();
  final pw = TextEditingController();
  final pw2 = TextEditingController();
  final name = TextEditingController();
  final stuid = TextEditingController();
  final major = TextEditingController();
  final phone = TextEditingController();

  String gender = '남';
  DateTime birth = DateTime.now();

  void dispose() {
    email.dispose();
    pw.dispose();
    pw2.dispose();
    name.dispose();
    stuid.dispose();
    major.dispose();
    phone.dispose();
  }
}

/// 스텝 스펙 (타이틀/컨텐트/검증 캡슐화)
class StepSpec {
  final String title;
  final Widget Function() contentBuilder;
  final Future<bool> Function()? validate; // 통과 시 true
  StepSpec({
    required this.title,
    required this.contentBuilder,
    this.validate,
  });
}

/// 타이틀 라벨 (화이트 배경 + 텍스트 스타일 통일)
Widget _stepLabel(String text) => Container(
  color: Colors.white,
  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
  child: Text(
    text,
    style: const TextStyle(
      fontFamily: "Pretendard",
      fontWeight: FontWeight.w600,
      color: Colors.black,
    ),
  ),
);

/// ===============================
/// Email Sign Up Page (리팩터 + BirthDateField 적용)
/// ===============================
class EmailSignUpPage extends StatefulWidget {
  const EmailSignUpPage({super.key});

  @override
  State<EmailSignUpPage> createState() => _EmailSignUpPageState();
}

class _EmailSignUpPageState extends State<EmailSignUpPage> {
  late final _SignUpModel m;
  final _accountFormKey = GlobalKey<FormState>();

  int currentStep = 0;

  @override
  void initState() {
    super.initState();
    m = _SignUpModel();
  }

  @override
  void dispose() {
    m.dispose();
    super.dispose();
  }

  /// 토스트 헬퍼
  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// 1단계(Account) 검증
  Future<bool> _validateAccount() async {
    // 이메일 형식 + 비밀번호 일치
    if (!_accountFormKey.currentState!.validate()) {
      _toast("이메일 형식이 아닙니다.");
      return false;
    }
    if (m.pw.text.isEmpty || m.pw2.text.isEmpty) {
      _toast("모든 필드를 입력해주세요.");
      return false;
    }
    if (m.pw.text != m.pw2.text) {
      _toast("비밀번호가 일치하지 않습니다.");
      return false;
    }
    return true;
  }

  /// 2단계(User Info) 검증
  Future<bool> _validateUserInfo() async {
    if (m.stuid.text.isEmpty ||
        m.name.text.isEmpty ||
        m.major.text.isEmpty ||
        m.phone.text.isEmpty) {
      _toast("필수 정보를 입력해주세요.");
      return false;
    }
    return true;
  }

  /// 최종 제출 (Firebase Auth + DB)
  Future<void> _submit() async {
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: m.email.text.trim(),
        password: m.pw.text,
      );

      await DBsvc().DBsignup(
        m.stuid.text,
        m.name.text,
        m.email.text,
        m.major.text,
        m.gender,
        m.birth,
        m.phone.text,
      );

      debugPrint("회원가입 성공: ${cred.user?.email}");
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyApp()),
      );
    } on FirebaseAuthException catch (e) {
      _toast("회원가입 실패: ${e.message}");
    }
  }

  /// 스텝 정의 (UI/검증 분리)
  List<StepSpec> _specs() => [
    StepSpec(
      title: 'Account',
      contentBuilder: () => Form(
        key: _accountFormKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 이메일
              AppTextFormField(
                controller: m.email,
                label: 'Email',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return "이메일을 입력해주세요";
                  const pattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
                  if (!RegExp(pattern).hasMatch(v)) {
                    return "올바른 이메일 형식이 아닙니다";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 비밀번호
              AppTextField(
                controller: m.pw,
                label: 'Password',
                icon: Icons.password,
                obscureText: true,
              ),
              const SizedBox(height: 16),

              // 비밀번호 확인
              AppTextField(
                controller: m.pw2,
                label: 'Password check',
                icon: Icons.password,
                obscureText: true,
              ),
            ],
          ),
        ),
      ),
      validate: _validateAccount,
    ),
    StepSpec(
      title: 'User Info',
      contentBuilder: () => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 학번
            AppTextField(
              controller: m.stuid,
              label: '학번',
              icon: Icons.badge,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 10),

            // 이름
            AppTextField(
              controller: m.name,
              label: '이름',
              icon: Icons.person,
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 10),

            // 학과 (Autocomplete)
            MajorField(majorController: m.major),
            const SizedBox(height: 10),

            // 전화번호
            PhoneNumberField(phoneNumController: m.phone),
            const SizedBox(height: 10),

            // 생년월일 (스타일 통일)
            _FieldShell(
              child: SizedBox(
                height: 60, // DatePicker 높이 유지
                child: Row(
                  children: [
                    const Icon(Icons.cake, color: kGreyBorder),
                    const SizedBox(width: 16),
                    const Text(
                      '생년월일',
                      style: TextStyle(
                        fontSize: 17,
                        fontFamily: "Pretendard",
                        fontWeight: FontWeight.w800,
                        color: kGreyBorder,),  // 다른 필드와 라벨 스타일 통일

                    ),
                    //const SizedBox(width: 10),
                    const Spacer(),
                    Expanded(
                      child: DatePicker(
                        onDateTimeChanged: (DateTime birthDate) {
                          setState(() {
                            m.birth = birthDate; // ← EmailSignUpPage
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 성별 라디오
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio<String>(
                  value: '남',
                  groupValue: m.gender,
                  onChanged: (value) => setState(() => m.gender = value!),
                ),
                const Text('남'),
                Radio<String>(
                  value: '여',
                  groupValue: m.gender,
                  onChanged: (value) => setState(() => m.gender = value!),
                ),
                const Text('여'),
              ],
            ),
          ],
        ),
      ),
      validate: _validateUserInfo,
    ),
    StepSpec(
      title: 'Complete',
      contentBuilder: () => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(title: Text('Email'), trailing: Text(m.email.text)),
            ListTile(title: Text('Student ID'), trailing: Text(m.stuid.text)),
            ListTile(title: Text('Name'), trailing: Text(m.name.text)),
            ListTile(title: Text('Major'), trailing: Text(m.major.text)),
            ListTile(title: Text('Gender'), trailing: Text(m.gender)),
            ListTile(title: Text('Phone No.'), trailing: Text(m.phone.text)),
            ListTile(
              title: Text('Birth'),
              trailing: Text(DateFormat('yyyy-MM-dd').format(m.birth)),
            ),
          ],
        )

      ),
      validate: () async => true,
    ),
  ];

  /// Stepper용 Step로 변환 (state/isActive/label 포함)
  List<Step> _buildSteps() {
    final s = _specs();
    return List.generate(s.length, (i) {
      return Step(
        state: currentStep > i ? StepState.complete : StepState.indexed,
        title: _stepLabel(s[i].title), // ⬅️ 타이틀 라벨(화이트 배경)
        content: s[i].contentBuilder(),
        isActive: currentStep >= i,
      );
    });
  }

  /// onStepContinue: 현재 스펙 검증 → 마지막이면 제출
  Future<void> _onContinue() async {
    final specs = _specs();
    final ok = await (specs[currentStep].validate?.call() ?? Future.value(true));
    if (!ok) return;

    if (currentStep == specs.length - 1) {
      await _submit();
    } else {
      setState(() => currentStep += 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (BuildContext ctx) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            title: const Text(
              "Sign up",
              style: TextStyle(
                fontFamily: "Pretendard",
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          body: Theme(
            // ⬇️ Stepper 라벨 영역 전체 배경 흰색
            data: Theme.of(context).copyWith(canvasColor: Colors.white,
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Color.fromRGBO(209, 87, 90, 1.0),
              onPrimary: Colors.white
            )),
            child: Stepper(
              steps: _buildSteps(),
              currentStep: currentStep,
              type: StepperType.horizontal,
              onStepTapped: (value) => setState(() => currentStep = value),

              // 진행/취소 로직 (검증 분리 후 간결)
              onStepContinue: _onContinue,
              onStepCancel: currentStep == 0
                  ? null
                  : () {
                // 이전 단계로 돌아가기
                setState(() => currentStep -= 1);
              },

              // 버튼 커스텀: 오른쪽 정렬 + 취소/다음(가입)
              controlsBuilder: (context, details) {
                final isLast = currentStep == _specs().length - 1;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.end, // 오른쪽 정렬
                  children: [
                    // 취소 버튼 (TextButton)
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        '취소',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 다음/가입 버튼 (FilledButton)
                    FilledButton(
                      style: appPrimaryButtonStyle(),
                      onPressed: details.onStepContinue, // Stepper onStepContinue 실행
                      child: Text(isLast ? '가입' : '다음'),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// ===============================
/// Google Sign Up Page (BirthDateField 적용)
/// ===============================
class GoogleSignUpPage extends StatefulWidget {
  const GoogleSignUpPage({super.key});

  @override
  State<GoogleSignUpPage> createState() => _GoogleSignUpPageState();
}

class _GoogleSignUpPageState extends State<GoogleSignUpPage> {
  String gender = '남';
  DateTime selectedStartDateTime = DateTime.now();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController stuidController = TextEditingController();
  final TextEditingController majorController = TextEditingController();
  final TextEditingController genderController = TextEditingController();
  final TextEditingController phoneNumController = TextEditingController();
  final TextEditingController birthController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    stuidController.dispose();
    majorController.dispose();
    genderController.dispose();
    phoneNumController.dispose();
    birthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AppTextField(
              controller: stuidController,
              label: '학번',
              icon: Icons.badge,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 10),
            AppTextField(
              controller: nameController,
              label: '이름',
              icon: Icons.person,
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 10),
            MajorField(majorController: majorController),
            const SizedBox(height: 10),

            PhoneNumberField(phoneNumController: phoneNumController),
            const SizedBox(height: 10),

            // 생년월일 (스타일 통일)
            SizedBox(
              height: 150,
              child: Row(
                children: [
                  const Text('생년월일'),
                  Expanded(
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

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio<String>(
                  value: '남',
                  groupValue: gender,
                  onChanged: (value) => setState(() => gender = value!),
                ),
                const Text('남'),
                Radio<String>(
                  value: '여',
                  groupValue: gender,
                  onChanged: (value) => setState(() => gender = value!),
                ),
                const Text('여'),
              ],
            ),

            const SizedBox(height: 32),
            FilledButton(
              style: appPrimaryButtonStyle(),
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
              child: const Text(
                "회원가입",
                style: TextStyle(
                  fontFamily: "Pretendard",
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// Fields: Major / PhoneNumber (로컬 스타일 적용)
/// ===============================
class MajorField extends StatelessWidget {
  final TextEditingController majorController;

  MajorField({super.key, required this.majorController});

  // 학과 목록
  final List<String> majors = const [
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
    return _FieldShell(
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return majors;
          }
          return majors.where((major) => major.contains(textEditingValue.text));
        },
        onSelected: (String selection) {
          majorController.text = selection;
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          // 컨트롤러 동기화
          controller.text = majorController.text;
          controller.addListener(() => majorController.text = controller.text);

          return TextField(
            controller: controller,
            focusNode: focusNode,
            cursorColor: kCursorGrey,
            decoration: const InputDecoration(
              border: InputBorder.none,
              icon: Icon(Icons.school, color: kGreyBorder),
              labelText: "학과",
              labelStyle: kLabelStyle,
            ),
            style: const TextStyle(fontFamily: "Pretendard"),
          );
        },
      ),
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
    return _FieldShell(
      child: TextField(
        controller: phoneNumController,
        keyboardType: TextInputType.phone,
        inputFormatters: [maskFormatter],
        cursorColor: kCursorGrey,
        decoration: const InputDecoration(
          border: InputBorder.none,
          icon: Icon(Icons.phone, color: kGreyBorder),
          labelText: '전화번호',
          labelStyle: kLabelStyle,
        ),
        style: const TextStyle(fontFamily: "Pretendard"),
      ),
    );
  }
}
