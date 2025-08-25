import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================
// 모델
// =============================
enum EntrySource { manual, csv }

typedef EntryId = String;

class TransactionEntry {
  final EntryId id;
  final DateTime date;
  final String description;
  final double amount;
  final String? category;
  final String? memo;
  final EntrySource source;
  final String? receiptPath;

  TransactionEntry({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    this.category,
    this.memo,
    required this.source,
    this.receiptPath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'description': description,
    'amount': amount,
    'category': category,
    'memo': memo,
    'source': source.name,
    'receiptPath': receiptPath,
  };

  static TransactionEntry fromJson(Map<String, dynamic> json) =>
      TransactionEntry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        description: json['description'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: json['category'] as String?,
        memo: json['memo'] as String?,
        source: (json['source'] == 'csv')
            ? EntrySource.csv
            : EntrySource.manual,
        receiptPath: json['receiptPath'] as String?,
      );
}



// ... TransactionEntry, EntrySource 등 다른 코드는 그대로 ...

class LedgerStore extends ChangeNotifier {
  late final DatabaseReference _dbRef; // final이지만 생성자에서 초기화
  final String clubname; // clubname을 저장할 변수

  final List<TransactionEntry> _entries = [];
  StreamSubscription<DatabaseEvent>? _dbSubscription;

  // 생성자에서 clubname을 필수로 받도록 수정
  LedgerStore({required this.clubname}) {
    // clubname을 사용하여 데이터베이스 경로를 동적으로 설정
    _dbRef = FirebaseDatabase.instance.ref('Club/$clubname/balance');
  }

  List<TransactionEntry> get entries => List.unmodifiable(_entries);
  // 나머지 getter들은 그대로 유지
  double get totalIncome =>
      _entries.where((e) => e.amount > 0).fold(0.0, (a, b) => a + b.amount);
  double get totalExpense => _entries
      .where((e) => e.amount < 0)
      .fold(0.0, (a, b) => a + b.amount.abs());
  double get balance => totalIncome - totalExpense;


  // SharedPreferences의 load 대신 실시간 리스너를 설정하는 함수
  void listenToData() {
    // 기존 리스너가 있다면 취소
    _dbSubscription?.cancel();

    _dbSubscription = _dbRef.onValue.listen((event) {
      final data = event.snapshot.value;
      _entries.clear();

      if (data != null && data is Map) {
        // Firebase는 데이터를 Map 형태로 반환합니다.
        data.forEach((key, value) {
          // Firebase에서 생성된 고유 키를 id로 사용합니다.
          final entryMap = Map<String, dynamic>.from(value as Map);
          entryMap['id'] = key; // 키를 id 필드에 주입
          _entries.add(TransactionEntry.fromJson(entryMap));
        });
      }

      // 날짜순으로 정렬
      _entries.sort((a, b) => b.date.compareTo(a.date));
      // 데이터가 변경되었음을 위젯에 알림
      notifyListeners();
    });
  }

  // _persist 함수는 더 이상 필요 없으므로 삭제합니다.

  // 데이터 추가: push()를 사용해 고유 키를 자동 생성하며 추가
  void add(TransactionEntry e) {
    _dbRef.push().set(e.toJson());
  }

  // 데이터 삭제: 전달받은 id(Firebase의 고유 키)로 자식 노드를 찾아 삭제
  void remove(EntryId id) {
    _dbRef.child(id).remove();
  }
  
  // 여러 데이터 추가/업데이트 (CSV용)
  void upsertMany(List<TransactionEntry> list) {
    // 중복 검사 로직은 그대로 유지
    bool isDup(TransactionEntry a, TransactionEntry b) {
      return a.date.year == b.date.year &&
          a.date.month == b.date.month &&
          a.date.day == b.date.day &&
          a.amount.toStringAsFixed(2) == b.amount.toStringAsFixed(2) &&
          a.description.trim() == b.description.trim();
    }
    
    // 추가할 항목만 필터링
    final newEntries = list.where((e) {
      return !_entries.any((existing) => isDup(existing, e));
    }).toList();

    // 여러 데이터를 한 번에 업데이트 (원자적 연산)
    final Map<String, dynamic> updates = {};
    for (final entry in newEntries) {
      // 새 키를 생성하고 해당 경로에 데이터를 추가
      final newKey = _dbRef.push().key;
      if (newKey != null) {
        updates[newKey] = entry.toJson();
      }
    }
    
    // 준비된 업데이트를 한 번에 전송
    if (updates.isNotEmpty) {
      _dbRef.update(updates);
    }
  }

  // 리소스 정리
  @override
  void dispose() {
    _dbSubscription?.cancel();
    super.dispose();
  }
}

// InheritedNotifier (DI)
class LedgerProvider extends InheritedNotifier<LedgerStore> {
  const LedgerProvider({
    super.key,
    required LedgerStore store,
    required super.child,
  }) : super(notifier: store);

  static LedgerStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LedgerProvider>()!.notifier!;

  @override
  bool updateShouldNotify(covariant InheritedNotifier<LedgerStore> oldWidget) =>
      true;
}

// =============================
// 이제 이 위젯만 쓰면 됨
// =============================
class LedgerWidget extends StatefulWidget {
    final String clubname;

  const LedgerWidget({
    super.key,
    required this.clubname, // 필수로 받도록 설정
  });

  @override
  State<LedgerWidget> createState() => _LedgerWidgetState();
}

class _LedgerWidgetState extends State<LedgerWidget> {
  late final LedgerStore store;
  String _query = '';
  @override
  void initState() {
    super.initState();
    store = LedgerStore(clubname: widget.clubname);
    // SharedPreferences에서 로드하는 대신, Firebase 데이터 리스너 시작
    store.listenToData();
  }
  
  // store 리소스를 위젯이 사라질 때 정리해주도록 dispose 추가
  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LedgerProvider(
      store: store,
      child: Scaffold(
        backgroundColor: Colors.white,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              backgroundColor: Color.fromRGBO(216, 162, 163, 1.0),
              heroTag: 'fab-upload', // ✅ 서로 다른 heroTag 필수
              onPressed: _openAddDialog,
              label: Text('수기 입력', style: TextStyle(color: Colors.white),),
              icon: const Icon(Icons.add, color: Colors.white,),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              backgroundColor: Color.fromRGBO(216, 162, 163, 1.0),
              heroTag: 'fab-add',
              onPressed: _pickAndImportCsv,
              label: Text('CSV 업로드', style: TextStyle(color: Colors.white),),
              icon: const Icon(Icons.upload_file, color: Colors.white,),
            ),
          ],
        ),


        body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  cursorColor: const Color.fromRGBO(119, 119, 119, 1.0),
                  decoration: InputDecoration(
                    labelText: '검색 (메모/적요/카테고리)',
                    prefixIcon: const Icon(Icons.search),

                    border: const UnderlineInputBorder(),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Color.fromRGBO(119, 119, 119, 1.0), // 포커스 시 밑줄 색
                        width: 1,
                      ),
                    ),

                    labelStyle: TextStyle(color: Colors.grey.shade600),
                    floatingLabelStyle: const TextStyle(
                      color: Color.fromRGBO(119, 119, 119, 1.0),
                      fontWeight: FontWeight.w600,
                    ),
                    prefixIconColor: MaterialStateColor.resolveWith(
                          (states) => states.contains(MaterialState.focused)
                          ? const Color.fromRGBO(119, 119, 119, 1.0)
                          : Colors.grey,
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              Expanded(child: _EntryList(query: _query)),
            ],

        ),
      ),
    );
  }

  Future<void> _openAddDialog() async {
    final created = await showDialog<TransactionEntry>(
      context: context,
      builder: (context) => AddEntryDialog(),
    );
    if (created != null) {
      store.add(created);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('거래 추가 완료')));
      }
    }
  }

  // 기존 _pickAndImportCsv 함수 대신
  Future<void> _pickAndImportCsv() async {
    // ... _pickAndImportCsv 함수 내부 ...
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) return;

      final file = File(path);
      // 토스뱅크 CSV는 euc-kr 인코딩인 경우가 많으므로 utf8 대신 사용해 볼 수 있습니다.
      // 만약 한글이 깨진다면 utf8 대신 latin1 이나 systemEncoding을 사용해보세요.
      final csvRaw = await file.readAsString(encoding: utf8);

      // 헤더가 9번째 줄에 있으므로 8줄을 건너뜁니다.
      final lines = const LineSplitter().convert(csvRaw);
      // 마지막 빈 줄이 있을 경우를 대비해 비어있지 않은 라인만 필터링
      final tableContent = lines
          .skip(8)
          .where((line) => line.trim().isNotEmpty)
          .join('\n');
      if (tableContent.isEmpty) {
        _showError('CSV에서 유효한 데이터를 찾을 수 없습니다.');
        return;
      }
      print(tableContent);

      // *** 중요: fieldDelimiter를 쉼표(,)로 수정 ***
      final rowsWithHeader = const CsvToListConverter(
        eol: '\n',
        fieldDelimiter: ',', // 탭('\t')에서 쉼표(',')로 변경
      ).convert(tableContent);

      if (rowsWithHeader.length < 2) {
        _showError('CSV에 데이터 행이 없습니다.');
        return;
      }

      final header = rowsWithHeader.first;
      final rows = rowsWithHeader.skip(1);

      // 컬럼 인덱스를 동적으로 찾도록 수정
      final dateIdx = _findHeaderIndex(header, ['거래 일시']);
      final descIdx = _findHeaderIndex(header, ['적요']);
      final amountIdx = _findHeaderIndex(header, ['거래 금액']);
      final memoIdx = _findHeaderIndex(header, ['메모']);

      if (dateIdx == null || descIdx == null || amountIdx == null) {
        _showError('필수 컬럼(거래 일시, 적요, 거래 금액)을 찾을 수 없습니다.');
        return;
      }

      final parsed = <TransactionEntry>[];
      for (final row in rows) {
        if (row.length <= dateIdx ||
            row.length <= descIdx ||
            row.length <= amountIdx)
          continue;

        final date = _parseDate(row[dateIdx]);
        final desc = row[descIdx].toString();
        final amount = _parseAmount(row[amountIdx]);
        final memo = (memoIdx != null && row.length > memoIdx)
            ? row[memoIdx].toString()
            : null;

        if (date == null) continue;

        parsed.add(
          TransactionEntry(
            id: UniqueKey().toString(),
            date: date,
            description: desc,
            amount: amount,
            memo: memo,
            source: EntrySource.csv,
          ),
        );
      }

      if (parsed.isNotEmpty) {
        store.upsertMany(parsed);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${parsed.length}건 CSV에서 가져왔습니다.')),
          );
        }
      }
    } catch (e) {
      _showError('CSV 처리 중 오류: $e');
    }
  }

  int? _findHeaderIndex(List header, List<String> candidates) {
    for (int i = 0; i < header.length; i++) {
      final h = header[i].toString().trim().toLowerCase();
      for (final c in candidates) {
        if (h.contains(c)) return i;
      }
    }
    return null;
  }

// 이 함수를 아래 코드로 교체하세요.
  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    final formats = [
      // *** 토스뱅크 형식을 여기에 추가! ***
      'yyyy.MM.dd HH:mm:ss', 
      
      'yyyy-MM-dd HH:mm:ss',
      'yyyy/MM/dd HH:mm:ss',
      'yyyy-MM-dd',
      'yyyy.MM.dd',
      'yyyy/MM/dd',
      'yyyyMMdd',
      'dd/MM/yyyy',
      'dd.MM.yyyy',
      'dd-MM-yyyy',
      'MM/dd/yyyy',
    ];
    for (final f in formats) {
      try {
        return DateFormat(f).parseStrict(s);
      } catch (_) {}
    }
    // 모든 형식에 실패하면 null 반환
    return null;
  }

  double _parseAmount(dynamic v) {
    if (v == null) return 0.0;
    final s = v.toString().replaceAll(',', '').replaceAll('₩', '').trim();
    try {
      return double.parse(s);
    } catch (_) {
      if (s.endsWith('-')) {
        final core = s.substring(0, s.length - 1).replaceAll(',', '');
        return -double.tryParse(core)!;
      }
      return 0.0;
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// =============================
// 나머지 UI 위젯들 (_SummaryBar, _EntryList, AddEntryDialog)
// 그대로 두면 됩니다 (길어서 생략)
// =============================
class _SummaryBar extends StatelessWidget {
  const _SummaryBar();

  @override
  Widget build(BuildContext context) {
    final store = LedgerProvider.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _KpiCard(title: '수입', value: store.totalIncome),
              const SizedBox(width: 12),
              _KpiCard(title: '지출', value: -store.totalExpense),
              const SizedBox(width: 12),
              _KpiCard(title: '잔액', value: store.balance, emphasize: true),
            ],
          ),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final double value;
  final bool emphasize;

  const _KpiCard({
    required this.title,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat.currency(symbol: '₩', decimalDigits: 0);
    return Expanded(
      child: Card(
        elevation: emphasize ? 2 : 0,
        color: emphasize
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Text(
                f.format(value),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// EntryList, AddEntryDialog도 그대로 넣으면 됩니다.
// =============================
// 거래 리스트
// =============================
class _EntryList extends StatelessWidget {
  final String query;
  const _EntryList({required this.query});

  @override
  Widget build(BuildContext context) {
    final store = LedgerProvider.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final q = query.toLowerCase();
        final list = store.entries.where((e) {
          if (q.isEmpty) return true;
          final content = '${e.description} ${e.memo ?? ''} ${e.category ?? ''}'
              .toLowerCase();
          return content.contains(q);
        }).toList();

        if (list.isEmpty) {
          return const Center(child: Text('거래가 없습니다. CSV 업로드 또는 수기 입력을 해보세요.'));
        }

        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (context, i) {
            final e = list[i];
            final fDate = DateFormat('yyyy.MM.dd').format(e.date);
            final fMoney = NumberFormat.currency(
              symbol: '₩',
              decimalDigits: 0,
            ).format(e.amount);
            final isIncome = e.amount > 0;

            return Dismissible(
              key: ValueKey(e.id),
              background: Container(color: Colors.redAccent.withOpacity(0.8)),
              onDismissed: (_) => LedgerProvider.of(context).remove(e.id),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isIncome
                      ? Color.fromRGBO(
                      87, 103, 209, 0.5) : Color.fromRGBO(
                      209, 87, 90, 0.5),
                  child: Icon(
                    isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                    color: Colors.black,
                  ),
                ),
                title: Text(
                  e.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${e.category ?? '미분류'} • $fDate'
                  '${(e.memo == null || e.memo!.isEmpty) ? '' : ' • ${e.memo}'}',
                ),
                trailing: Text(
                  fMoney,
                  style: TextStyle(
                    color: isIncome ? Color.fromRGBO(
                        87, 103, 209, 1.0) : Color.fromRGBO(
                        209, 87, 90, 1.0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// =============================
// 수기 입력 다이얼로그
// =============================
class AddEntryDialog extends StatefulWidget {
  const AddEntryDialog({super.key});

  @override
  State<AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends State<AddEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  DateTime _date = DateTime.now();
  final _desc = TextEditingController();
  final _amount = TextEditingController();
  final _category = TextEditingController();
  final _memo = TextEditingController();
  bool _isIncome = true; // 수입/지출 토글

  @override
  void dispose() {
    _desc.dispose();
    _amount.dispose();
    _category.dispose();
    _memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('거래 수기 입력'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _desc,
                      decoration: const InputDecoration(labelText: '적요/설명'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '설명을 입력하세요' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('수입'),),
                      ButtonSegment(value: false, label: Text('지출')),
                    ],
                    selected: {_isIncome},
                    onSelectionChanged: (s) =>
                        setState(() => _isIncome = s.first),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                decoration: const InputDecoration(labelText: '금액 (숫자)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '금액을 입력하세요';
                  final parsed = double.tryParse(v.replaceAll(',', ''));
                  if (parsed == null || parsed <= 0) return '유효한 양수 금액을 입력하세요';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _category,
                      decoration: const InputDecoration(labelText: '카테고리 (선택)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _memo,
                      decoration: const InputDecoration(labelText: '메모 (선택)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '날짜: ${DateFormat('yyyy.MM.dd').format(_date)}',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('날짜 선택'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('취소', style: TextStyle(color: Colors.black),),
        ),
        FilledButton(

          onPressed: () {

            if (_formKey.currentState!.validate()) {
              final value = double.parse(_amount.text.replaceAll(',', ''));
              final signed = _isIncome ? value : -value;
              final entry = TransactionEntry(
                id: UniqueKey().toString(),
                date: _date,
                description: _desc.text.trim(),
                amount: double.parse(signed.toStringAsFixed(2)),
                category: _category.text.trim().isEmpty
                    ? null
                    : _category.text.trim(),
                memo: _memo.text.trim().isEmpty ? null : _memo.text.trim(),
                source: EntrySource.manual,
              );
              Navigator.pop(context, entry);
            }
          },
          child: const Text('추가'),
        ),
      ],
    );
  }
}
