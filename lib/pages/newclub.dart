import 'dart:io';

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

  Future<void> _pickImage() async {
    final picked =
    await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
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
      // clubName에 공백/특수문자가 있으면 경로 문제 예방
      final safeName = clubName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final ref = FirebaseStorage.instance
          .ref()
          .child('Club/$safeName/info/$fileName');

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

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();

    if (name.isEmpty || desc.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('모든 항목을 입력해주세요.')));
      return;
    }

    setState(() => _uploading = true);

    try {
      leaderid = await user_stuid();

      // 1) 이미지가 있으면 Storage 업로드
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImageAndGetUrl(
          clubName: name,
          file: _selectedImage!,
        );
      }

      // 2) DB 저장
      final infoRef = FirebaseDatabase.instance.ref("Club/$name/info");
      await infoRef.set({
        "clubname": name,
        "clubcat": _selectedCategory,
        "clubdesc": desc,
        "leaderid": leaderid,
        "clubimg": imageUrl ?? "",
      });

      // 3) 개설자 멤버로 추가 (members/{leaderid}: true)
      if (leaderid != null && leaderid!.isNotEmpty) {
        await FirebaseDatabase.instance
            .ref("Club/$name/members/$leaderid")
            .set(true);

        // 4) 개설자의 Person/{sid}/club 에도 추가
        final myClubsRef =
        FirebaseDatabase.instance.ref("Person/$leaderid/club");
        final snapshot = await myClubsRef.get();
        if (snapshot.exists) {
          await myClubsRef
              .child("club${snapshot.children.length + 1}")
              .set(name);
        } else {
          await myClubsRef.child("club1").set(name);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('동아리를 개설했습니다.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('개설 실패: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);

    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('동아리 개설')),
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
                    decoration: const InputDecoration(
                      labelText: '동아리명',
                      border: OutlineInputBorder(),
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
                    decoration: const InputDecoration(
                      labelText: '동아리 분류',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 설명
                  TextField(
                    controller: _descController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '동아리 설명',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 제출 버튼
                  Center(
                    child: ElevatedButton(
                      onPressed: _uploading ? null : _submit,
                      child: const Text('개설하기'),
                    ),
                  ),
                ],

              ),
            ),
          ),
        ],
      ),
    );
  }
}
