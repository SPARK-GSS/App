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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 항목을 입력해주세요.')),
      );
      return;
    }

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
      await ref.child("club${snapshot.children.length + 1}").set(name);
    } else {
      await ref.child("club1").set(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('동아리 개설'), backgroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 동아리명 (스타일 적용)
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

            // 이미지 업로드 (동일)
            GestureDetector(
              onTap: _pickImage,
              child: _selectedImage == null
                  ? Container(
                height: 150,
                width: double.infinity,
                color: Colors.grey[200],
                child: const Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
              )
                  : Image.file(_selectedImage!, height: 150, fit: BoxFit.cover),
            ),

            const SizedBox(height: 16),

            // 동아리 분류 (Dropdown + 동일 스타일의 InputDecoration)
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              isExpanded: true,
              items: _categories
                  .map((c) => DropdownMenuItem(
                value: c,
                child: const SizedBox(
                  height: 44,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      // 메뉴 텍스트
                      // 항목 텍스트 스타일은 여기서 지정
                      // (필요없으면 기본값으로 두셔도 됩니다)
                      '',
                    ),
                  ),
                ),
              ))
                  .toList()
              // 위에서 ''로 비워둔 텍스트를 실제 값으로 교체
                  .asMap()
                  .entries
                  .map((e) => DropdownMenuItem<String>(
                value: _categories[e.key],
                child: Text(
                  _categories[e.key],
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                ),
              ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val),

              dropdownColor: Colors.white,
              menuMaxHeight: 320,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(Icons.arrow_drop_down),
              iconEnabledColor: const Color.fromRGBO(224, 224, 224, 1.0),
              style: const TextStyle(fontSize: 16),

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

            // 동아리 설명 (스타일 적용)
            TextField(
              controller: _descController,
              maxLines: 5,
              cursorColor: const Color.fromRGBO(119, 119, 119, 1.0),
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

            const SizedBox(height: 16),

            // 제출 버튼 (동일)
            Center(
              child: SizedBox(
                width: 100,
                height: 40,
              child: ElevatedButton(
                onPressed: () {
                  _submit();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(216, 162, 163, 1.0),
                  foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)
                    )
                ),
                child: const Text('개설하기'),
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
