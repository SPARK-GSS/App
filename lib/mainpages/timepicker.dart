import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 날짜 + 시간 선택 위젯
class DateTimePickerExample extends StatefulWidget {
  final Function(DateTime) onDateTimeChanged;

  const DateTimePickerExample({Key? key, required this.onDateTimeChanged})
      : super(key: key);

  @override
  State<DateTimePickerExample> createState() => _DateTimePickerExampleState();
}

class _DateTimePickerExampleState extends State<DateTimePickerExample> {
  DateTime selectedDate = DateTime.now();
  Duration selectedTime =
  Duration(hours: DateTime.now().hour, minutes: DateTime.now().minute);

  void _notifyParent() {
    final combinedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.inHours,
      selectedTime.inMinutes % 60,
    );
    widget.onDateTimeChanged(combinedDateTime);
  }

  void _showDatePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white, // ✅ 배경색 지정
      builder: (_) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              _buildSheetHeader(),
              Expanded(
                child: CupertinoDatePicker(
                  initialDateTime: selectedDate,
                  maximumDate: DateTime(2025, 12, 31),
                  minimumYear: 2025,
                  maximumYear: 2025,
                  mode: CupertinoDatePickerMode.date,
                  onDateTimeChanged: (DateTime value) {
                    setState(() => selectedDate = value);
                    _notifyParent();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTimePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white, // ✅ 배경색 지정
      builder: (_) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              _buildSheetHeader(),
              Expanded(
                child: CupertinoTimerPicker(
                  initialTimerDuration: selectedTime,
                  mode: CupertinoTimerPickerMode.hm,
                  onTimerDurationChanged: (Duration value) {
                    setState(() => selectedTime = value);
                    _notifyParent();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CupertinoButton(
          child: const Text("Cancel", style: TextStyle(color: Colors.red)),
          onPressed: () => Navigator.pop(context),
        ),
        CupertinoButton(
          child: const Text("Done",
              style: TextStyle(color: Color.fromRGBO(216, 162, 163, 1.0))),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final combinedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.inHours,
      selectedTime.inMinutes % 60,
    );

    return Container(
      color: Colors.white,
      height: 50,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _showDatePicker,
              child: Center(
                child: Text(
                  DateFormat('yyyy-MM-dd').format(selectedDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _showTimePicker,
              child: Center(
                child: Text(
                  DateFormat('HH:mm').format(combinedDateTime),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 날짜만 선택 위젯
class DatePicker extends StatefulWidget {
  final Function(DateTime) onDateTimeChanged;

  const DatePicker({super.key, required this.onDateTimeChanged});

  @override
  State<DatePicker> createState() => _DatePickerState();
}

class _DatePickerState extends State<DatePicker> {
  DateTime selectedDate = DateTime.now();

  void _notifyParent() {
    final combinedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    widget.onDateTimeChanged(combinedDateTime);
  }

  void _showDatePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (_) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              _buildSheetHeader(),
              Expanded(
                child: CupertinoDatePicker(
                  initialDateTime: selectedDate,
                  maximumDate: DateTime(2025, 12, 31),
                  minimumYear: 1950,
                  maximumYear: 2025,
                  mode: CupertinoDatePickerMode.date,
                  onDateTimeChanged: (DateTime value) {
                    setState(() => selectedDate = value);
                    _notifyParent();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CupertinoButton(
          child: const Text("Cancel", style: TextStyle(color: Colors.red)),
          onPressed: () => Navigator.pop(context),
        ),
        CupertinoButton(
          child: const Text("Done",
              style: TextStyle(color: Color.fromRGBO(216, 162, 163, 1.0))),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      height: 50,
      child: GestureDetector(
        onTap: _showDatePicker,
        child: Center(
          child: Text(
            DateFormat('yyyy-MM-dd').format(selectedDate),
            style: const TextStyle(fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
