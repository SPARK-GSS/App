import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateTimePickerExample extends StatefulWidget {
  final Function(DateTime) onDateTimeChanged;  // 부모에게 전달할 콜백

  const DateTimePickerExample({Key? key, required this.onDateTimeChanged}) : super(key: key);

  @override
  State<DateTimePickerExample> createState() => _DateTimePickerExampleState();
}

class _DateTimePickerExampleState extends State<DateTimePickerExample> {
  DateTime selectedDate = DateTime.now();
  Duration selectedTime = Duration(hours: DateTime.now().hour, minutes: DateTime.now().minute);

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
                    setState(() {
                      selectedDate = value;
                    });
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
                    setState(() {
                      selectedTime = value;
                    });
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
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.red),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        CupertinoButton(
          child: const Text('Done'),
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

    return Scaffold(
      body: Center(
        child: SizedBox(
          height: 50, // Row 높이 제한
          child: Row(
            children: [
              Expanded(
                child:  IconButton(onPressed: _showDatePicker, icon: Text(DateFormat('yyyy-MM-dd').format(selectedDate)))
                // child: Column(
                //   mainAxisAlignment: MainAxisAlignment.center,
                //   children: [
                //     Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                //     IconButton(
                //       onPressed: _showDatePicker,
                //       icon: Icon(Icons.calendar_today),
                //     ),
                //   ],
                // ),
              ),
              Expanded(
                //child: Column(
                  child:  IconButton(onPressed: _showTimePicker, icon: Text(DateFormat('HH:mm').format(combinedDateTime)))
                //   mainAxisAlignment: MainAxisAlignment.center,
                //   children: [
                //     Text(DateFormat('HH:mm').format(combinedDateTime)),
                //     IconButton(
                //       onPressed: _showTimePicker,
                //       icon: Icon(Icons.access_time),
                //     ),
                //   ],
                // ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
