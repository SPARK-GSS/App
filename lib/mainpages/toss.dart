import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class CsvReaderExample extends StatefulWidget {
  const CsvReaderExample({super.key});

  @override
  State<CsvReaderExample> createState() => _CsvReaderExampleState();
}

class _CsvReaderExampleState extends State<CsvReaderExample> {
  List<List<dynamic>> _rows = [];

  Future<void> _pickAndReadCsv() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null) return;

    final file = File(result.files.single.path!);
    final contents = await file.readAsString(encoding: utf8);

    // 줄 단위 분리
    final lines = const LineSplitter().convert(contents);

    // 앞에 7줄 무시 (8번째 줄부터 읽기)
    final tableLines = lines.skip(7).join("\n");

    final rows = const CsvToListConverter().convert(tableLines);

    setState(() {
      _rows = rows;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("토스뱅크 CSV 읽기")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _pickAndReadCsv,
            child: const Text("CSV 불러오기"),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _rows.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_rows[index].join(" | ")),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
