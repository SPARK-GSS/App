// lib/pages/edit_profile.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart' as fs;
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _majorCtrl = TextEditingController(); // 전공

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance;

  bool _isLoading = false;
  bool _uploading = false;

  String? _studentId; // Person/{studentId}
  String? _photoUrl;  // DB 또는 Auth의 photoURL

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      final email = user?.email;
      if (user == null || email == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("로그인이 필요합니다.")),
        );
        Navigator.pop(context);
        return;
      }

      // email로 Person/{studentId} 찾기
      final snap = await _db.ref('Person').orderByChild('email').equalTo(email).get();
      if (!snap.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("사용자 정보를 찾을 수 없습니다.")),
        );
        Navigator.pop(context);
        return;
      }

      final map = (snap.value as Map);
      final entry = map.entries.first;
      _studentId = entry.key.toString();

      final person = Map<String, dynamic>.from(entry.value as Map);
      _nameCtrl.text  = (person['name']  ?? user.displayName ?? '').toString();
      _majorCtrl.text = (person['major'] ?? '').toString();
      _photoUrl       = (person['photoUrl'] ?? user.photoURL ?? '').toString();
      if (_photoUrl!.isEmpty) _photoUrl = null;

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("불러오기 실패: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 갤러리 → Storage 업로드 → DB/Auth 업데이트
  Future<void> _pickAndUploadPhoto() async {
    if (_studentId == null) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null) return;

      setState(() => _uploading = true);

      final file = File(picked.path);
      final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'profile_photos/$_studentId/$filename';
      final ref = fs.FirebaseStorage.instance.ref(path);

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      // DB 업데이트
      await _db.ref('Person/$_studentId').update({'photoUrl': url});

      // Auth 표시용 업데이트
      final user = _auth.currentUser;
      if (user != null) {
        await user.updatePhotoURL(url);
        await user.reload();
      }

      if (!mounted) return;
      setState(() {
        _photoUrl = url;
        _uploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("프로필 사진이 저장되었습니다.")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("업로드 실패: $e")),
      );
    }
  }

  /// 이름 + 전공 저장
  Future<void> _saveProfile() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    final name  = _nameCtrl.text.trim();
    final major = _majorCtrl.text.trim();

    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null || _studentId == null) throw "인증/식별 정보가 없습니다.";

      await _db.ref('Person/$_studentId').update({
        'name': name,
        'major': major,
      });

      await user.updateDisplayName(name.isEmpty ? null : name);
      await user.reload();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("프로필이 저장되었습니다.")),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("저장 실패: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _majorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("프로필 수정"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: (_isLoading || _uploading) ? null : _saveProfile,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color.fromRGBO(216, 162, 163, 1.0),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontFamily: "Pretendard",
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        child: const Text("저장"),
                      ),
                    ),

                    if (_uploading) const LinearProgressIndicator(minHeight: 2),

                    const SizedBox(height: 8),
                    // 프로필 사진 프리뷰
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: const Color(0xFFEDEDED),
                      backgroundImage: (_photoUrl != null)
                          ? NetworkImage(_photoUrl!)
                          : null,
                      child: (_photoUrl == null)
                          ? const Icon(Icons.person, size: 42, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // 사진 등록/수정 텍스트 버튼
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: _uploading ? null : _pickAndUploadPhoto,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color.fromRGBO(216, 162, 163, 1.0),
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: Text(_photoUrl == null ? "프로필 사진 등록하기" : "프로필 사진 바꾸기"),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 이름2
                    TextFormField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "이름을 입력해주세요." : null,
                      cursorColor: const Color.fromRGBO(119, 119, 119, 1.0),
                      decoration: InputDecoration(
                        labelText: "이름",
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(color: Colors.grey, width: 1),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(color: Colors.black, width: 1),
                        ),
                        floatingLabelStyle: const TextStyle(
                          color: Color.fromRGBO(119, 119, 119, 1.0),
                          fontWeight: FontWeight.w600,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 전공
                    TextFormField(
                      controller: _majorCtrl,
                      textInputAction: TextInputAction.done,
                      cursorColor: const Color.fromRGBO(119, 119, 119, 1.0),
                      decoration: InputDecoration(
                        labelText: "전공",
                        //hintText: "전공을 입력해주세요",
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(color: Colors.grey, width: 1),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(color: Colors.black, width: 1),
                        ),
                        floatingLabelStyle: const TextStyle(
                          color: Color.fromRGBO(119, 119, 119, 1.0),
                          fontWeight: FontWeight.w600,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onFieldSubmitted: (_) => _saveProfile(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
