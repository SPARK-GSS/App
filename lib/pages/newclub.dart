import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:gss/services/AuthService.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ClubCreatePage extends StatefulWidget {
  @override
  _ClubCreatePageState createState() => _ClubCreatePageState();
}

class _ClubCreatePageState extends State<ClubCreatePage> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String? _selectedCategory;
  File? _selectedImage;
  String? leaderid;

  final List<String> _categories = ['스포츠', '문화', '봉사', '학술', '기타'];

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();
    if (name.isEmpty ||
        desc.isEmpty ||
        _selectedCategory == null ||
        _selectedImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('모든 항목을 입력해주세요.')));
      return;
    }

    // 여기서 서버 전송 로직 or Firebase 저장 로직 작성 가능
    print('동아리명: $name');
    print('동아리 설명: $desc');
    print('분류: $_selectedCategory');
    print('이미지: ${_selectedImage!.path}');

    leaderid = await user_stuid();

    DatabaseReference ref = FirebaseDatabase.instance.ref("Club/$name/info/");
    await ref.set({
      "clubname": name,
      "clubcat": _selectedCategory,
      "clubdesc": desc,
      //"clubimg": _selectedImage,
      "leaderid": leaderid,
    });

    ref = FirebaseDatabase.instance.ref("Person/$leaderid/club/");
    final snapshot = await ref.get();

    if (snapshot.exists) {
      // children.length = 하위 항목 개수
      await ref.child("club${snapshot.children.length + 1}").set(name);
    } else {
      await ref.child("club1").set(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('동아리 개설')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 동아리명
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '동아리명',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            // 이미지 업로드
            GestureDetector(
              onTap: _pickImage,
              child: _selectedImage == null
                  ? Container(
                      height: 150,
                      width: double.infinity,
                      color: Colors.grey[200],
                      child: Icon(
                        Icons.add_a_photo,
                        size: 50,
                        color: Colors.grey,
                      ),
                    )
                  : Image.file(_selectedImage!, height: 150, fit: BoxFit.cover),
            ),
            SizedBox(height: 16),

            // 분류 선택
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val),
              decoration: InputDecoration(
                labelText: '동아리 분류',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            // 설명
            TextField(
              controller: _descController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: '동아리 설명',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 24),

            // 제출 버튼
            Center(
              child: ElevatedButton(
                onPressed: () {
                  _submit();
                  Navigator.of(context).pop();
                },
                child: Text('개설하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
