import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:gss/services/AuthService.dart';
import 'package:image_picker/image_picker.dart';

class ClubCreatePage extends StatefulWidget {
  const ClubCreatePage({super.key});

  @override
  State<ClubCreatePage> createState() => _ClubCreatePageState();
}

class _ClubCreatePageState extends State<ClubCreatePage> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String? _selectedCategory;
  File? _selectedImage;
  String? leaderid;

  bool _uploading = false;

  final List<String> _categories = ['스포츠', '문화', '봉사', '학술', '기타'];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  /// Storage 업로드 → 다운로드 URL 반환
  Future<String?> _uploadImageAndGetUrl({
    required String clubName,
    required File file,
  }) async {
    try {
      // 경로 안전 처리 (공백/특수문자 치환)
      final safeName = clubName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final ref =
      FirebaseStorage.instance.ref().child('Club/$safeName/info/$fileName');

      final task = ref.putFile(file);
      await task;
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('이미지 업로드 실패: $e')));
      }
      return null;
    }
  }

  /// 클럽 이름 중복 검사:
  /// 1) 이미 승인된 클럽(Club/{name}) 존재?
  /// 2) 이미 대기열(App/pendingClubs/{name})에 존재?
  Future<String?> _validateDuplicateName(String name) async {
    // Club/{name}
    final approved = await FirebaseDatabase.instance.ref('Club/$name').get();
    if (approved.exists) {
      return '이미 존재하는 동아리명입니다.';
    }
    // App/pendingClubs/{name}
    final pending =
    await FirebaseDatabase.instance.ref('App/pendingClubs/$name').get();
    if (pending.exists) {
      return '이미 승인 대기 중인 동아리명입니다.';
    }
    return null;
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();

    if (name.isEmpty || desc.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('모든 항목을 입력해주세요.')));
      return;
    }
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('대표 이미지를 선택해주세요.')));
      return;
    }

    setState(() => _uploading = true);

    try {
      // (선택) 이름 포맷 간단 검증: 공백만/특수문자 과다 방지
      if (name.length < 2) {
        throw '동아리명은 2자 이상이어야 합니다.';
      }

      // 중복 검사
      final dup = await _validateDuplicateName(name);
      if (dup != null) {
        throw dup;
      }

      leaderid = await user_stuid();
      final requesterEmail =
          FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';

      // 이미지 업로드
      final imageUrl =
      await _uploadImageAndGetUrl(clubName: name, file: _selectedImage!);

      // 대기열에 신청 데이터 적재 (승인/반려는 Firebase Console에서 처리)
      final pendingRef =
      FirebaseDatabase.instance.ref('ClubPending/$name/info');
      await pendingRef.set({
        'clubname': name,
        'clubcat': _selectedCategory,
        'clubdesc': desc,
        'leaderid': leaderid ?? '',
        'clubimg': imageUrl ?? '',
        'requestedAt': DateTime.now().millisecondsSinceEpoch,
        'requestedByEmail': requesterEmail,
        'status': 'pending', // 표시용(관리 편의)
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('신청이 등록되었습니다. 관리자 승인 후 동아리 목록에 표시됩니다.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('신청 실패: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);

    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('동아리 개설'), backgroundColor: Colors.white,),
      body: Column(
        children: [
          if (_uploading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 동아리명
                  TextField(
                    controller: _nameController,
                    cursorColor: const Color.fromRGBO(119, 119, 119, 1.0),
                    decoration: const InputDecoration(
                      labelText: '동아리명',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        borderSide: BorderSide(color: Colors.grey, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        borderSide: BorderSide(color: Color.fromRGBO(119, 119, 119, 1.0), width: 2),
                      ),
                      floatingLabelStyle: TextStyle(
                        color: Color.fromRGBO(119, 119, 119, 1.0),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 이미지 업로드
                  GestureDetector(
                    onTap: _pickImage,
                    child: _selectedImage == null
                        ? Container(
                      height: 150,
                      width: double.infinity,
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.add_a_photo,
                        size: 50,
                        color: Colors.grey,
                      ),
                    )
                        : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImage!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 분류 선택
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: _categories
                        .map(
                          (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c),

                      ),
                    )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val),
                    dropdownColor: Colors.white,
                    decoration: const InputDecoration(
                      labelText: '동아리 분류',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        borderSide: BorderSide(color: Colors.grey, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        borderSide: BorderSide(color: Color.fromRGBO(119, 119, 119, 1.0), width: 2),
                      ),
                      floatingLabelStyle: TextStyle(
                        color: Color.fromRGBO(119, 119, 119, 1.0),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 설명
                  TextField(
                    controller: _descController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '동아리 설명',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        borderSide: BorderSide(color: Colors.grey, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        borderSide: BorderSide(color: Color.fromRGBO(119, 119, 119, 1.0), width: 2),
                      ),
                      floatingLabelStyle: TextStyle(
                        color: Color.fromRGBO(119, 119, 119, 1.0),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 제출 버튼
                  Center(
                    child: SizedBox(
                      width: 100,
                      height: 40,

                    child: ElevatedButton(
                      onPressed: _uploading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(216, 162, 163, 1.0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)
                          )
                      ),
                      child: const Text('개설하기'),
                    ),
                  ),),
                ],

              ),
            ),
          ),
        ],
      ),
    );
  }
}
