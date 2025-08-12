import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:gss/mainpages/timepicker.dart';

class CalendarApp extends StatefulWidget {
  final String clubName;
  const CalendarApp({super.key, required this.clubName});

  @override
  State<CalendarApp> createState() => _CalendarAppState();
}

class _CalendarAppState extends State<CalendarApp> {
  late CalendarController controller;
  late MeetingDataSource events;

  Meeting? selectedAppointment;
  late DateTime startDate;
  late TimeOfDay startTime;
  late DateTime endDate;
  late TimeOfDay endTime;
  bool isAllDay = false;
  String subject = '';
  String notes = '';
  int selectedColorIndex = 0;
  List<Color> colorCollection = [Colors.green, Colors.blue, Colors.orange, Colors.red, Colors.purple, Colors.yellow];
  List<String> timeZoneCollection = ['UTC', 'Asia/Seoul'];
  int selectedTimeZoneIndex = 0;

  @override
  void initState() {
    controller = CalendarController();
    events = MeetingDataSource([]); ;
    _loadMeetings();
    super.initState();
  }

  void _loadMeetings() async {
    final meetings = await _getDataSource();
    setState(() {
      events = MeetingDataSource(meetings);
    });
  }

  Future<List<Meeting>> _getDataSource() async {
    final dbRef = FirebaseDatabase.instance.ref(
      "Club/${widget.clubName}/calendar",
    );
    final snapshot = await dbRef.get();

    final List<Meeting> meetings = <Meeting>[];

    if (snapshot.exists) {
      final data = snapshot.value;
      if (data is Map<dynamic, dynamic>) {
        data.forEach((key, value) {
          // value는 Map 형태로 저장된 약속 정보임을 가정
          // 예: {
          //   "StartTime": "2025-08-11T09:00:00.000Z",
          //   "EndTime": "2025-08-11T11:00:00.000Z",
          //   "Subject": "Meeting Title"
          // }

          final startStr = value['StartTime'] as String?;
          final endStr = value['EndTime'] as String?;
          final subject = value['Subject'] as String? ?? '(No title)';
          final colorIndex = value['colorIndex'] as int? ?? 0;
          final isAllDay = value['isAllDay'] as bool? ?? false;
          if (startStr != null && endStr != null) {
            final startTime = DateTime.parse(startStr);
            final endTime = DateTime.parse(endStr);

            meetings.add(
              Meeting(subject, startTime, endTime, colorCollection[colorIndex], isAllDay),
            );
          }
        });
      }
    }

    return meetings;
  }

  void onCalendarTapped(CalendarTapDetails details) {
    if (details.targetElement != CalendarElement.calendarCell &&
        details.targetElement != CalendarElement.appointment) {
      return;
    }

    selectedAppointment = null;
    isAllDay = false;
    selectedColorIndex = 0;
    selectedTimeZoneIndex = 0;
    subject = '';
    notes = '';

    if (controller.view == CalendarView.month) {
      controller.view = CalendarView.day;
    } else {
      if (details.appointments != null && details.appointments!.isNotEmpty) {
        final Meeting meetingDetails = details.appointments![0];
        startDate = meetingDetails.from;
        endDate = meetingDetails.to;
        isAllDay = meetingDetails.isAllDay;
        selectedColorIndex = colorCollection.indexOf(meetingDetails.background);
        subject = meetingDetails.eventName == '(No title)'
            ? ''
            : meetingDetails.eventName;
        notes = meetingDetails.description ?? '';
        selectedAppointment = meetingDetails;
      } else {
        final DateTime date = details.date!;
        startDate = date;
        endDate = date.add(const Duration(hours: 1));
      }

      startTime = TimeOfDay(hour: startDate.hour, minute: startDate.minute);
      endTime = TimeOfDay(hour: endDate.hour, minute: endDate.minute);
    }
  }

  void saveAppointment() {
    final List<Meeting> meetings = <Meeting>[];

    if (selectedAppointment != null) {
      events.appointments!.remove(selectedAppointment);
      events.notifyListeners(CalendarDataSourceAction.remove, [
        selectedAppointment!,
      ]);
    }

    final newMeeting = Meeting(
      subject == '' ? '(No title)' : subject,
      startDate,
      endDate,
      colorCollection[selectedColorIndex],
      isAllDay,
      startTimeZone: selectedTimeZoneIndex == 0
          ? ''
          : timeZoneCollection[selectedTimeZoneIndex],
      endTimeZone: selectedTimeZoneIndex == 0
          ? ''
          : timeZoneCollection[selectedTimeZoneIndex],
      description: notes,
    );

    meetings.add(newMeeting);

    final dbRef = FirebaseDatabase.instance.ref(
      "Club/${widget.clubName}/calendar",
    );
    dbRef
        .push()
        .set({
          "StartTime": startDate.toIso8601String(),
          "EndTime": endDate.toIso8601String(),
          "Subject": subject,
          "isAllDay": isAllDay,
          "colorIndex": selectedColorIndex
        })
        .then((_) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Successfully Added')));
        })
        .catchError((error) {
          print(error);
        });

    events.appointments!.add(newMeeting);
    events.notifyListeners(CalendarDataSourceAction.add, meetings);

    selectedAppointment = null;
    //.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AppointmentEditor()),
          );

          if (result != null) {
            setState(() {
              subject = result['subject'] ?? '';
              notes = result['notes'] ?? '';
              startDate = result['startDate'] ?? DateTime.now();
              endDate =
                  result['endDate'] ?? DateTime.now().add(Duration(hours: 1));
              isAllDay = result['isAllDay'] ?? 'false';
              selectedColorIndex = result['colorIndex'] ?? 0;
            });
            saveAppointment(); // 부모의 saveAppointment 함수 호출해서 저장
          }
          // Navigator.push(context,             MaterialPageRoute(
          //     builder: (context) => CalendarApp(clubName: widget.clubName),
          //   ),);
        },
      ),
      body: SfCalendar(
        view: CalendarView.month,
        controller: controller,
        dataSource: events,
        monthViewSettings: const MonthViewSettings(
          showAgenda: true,
          appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
        ),
        //onTap: onCalendarTapped,
        allowAppointmentResize: true,
      ),
    );
  }
}

class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<Meeting> source) {
    appointments = source;
  }

  @override
  DateTime getStartTime(int index) => _getMeetingData(index).from;

  @override
  DateTime getEndTime(int index) => _getMeetingData(index).to;

  @override
  String getSubject(int index) => _getMeetingData(index).eventName;

  @override
  Color getColor(int index) => _getMeetingData(index).background;

  @override
  bool isAllDay(int index) => _getMeetingData(index).isAllDay;

  Meeting _getMeetingData(int index) {
    final dynamic meeting = appointments![index];
    return meeting as Meeting;
  }
}

class Meeting {
  Meeting(
    this.eventName,
    this.from,
    this.to,
    this.background,
    this.isAllDay, {
    this.startTimeZone = '',
    this.endTimeZone = '',
    this.description = '',
  });

  String eventName;
  DateTime from;
  DateTime to;
  Color background;
  bool isAllDay;
  String startTimeZone;
  String endTimeZone;
  String? description;
}

class AppointmentEditor extends StatefulWidget {
  //final VoidCallback onSave;
  const AppointmentEditor({Key? key}) : super(key: key);

  @override
  State<AppointmentEditor> createState() => _AppointmentEditorState();
}

class _AppointmentEditorState extends State<AppointmentEditor> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime selectedStartDateTime = DateTime.now();
  DateTime selectedEndDateTime = DateTime.now();
  bool isAllDay = false;
  int selectedColorIndex = 0;
  List<Color> colorCollection = [Colors.green, Colors.blue, Colors.orange, Colors.red, Colors.purple, Colors.yellow];


  @override
  void dispose() {
    _subjectController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  appBar: AppBar(title: const Text('Add Appointment')),
  body: SingleChildScrollView(  // 키보드 올라와도 스크롤 가능하도록
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _subjectController,
          decoration: const InputDecoration(
            labelText: 'Subject',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Notes',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 20),

        Text('Select Color', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        // 색상 선택 버튼
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(colorCollection.length, (index) {
            final color = colorCollection[index];
            final isSelected = selectedColorIndex == index;
            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedColorIndex = index;
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.black, width: 3)
                      : null,
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 20),

        // 하루 종일 체크박스
        Row(
          children: [
            Checkbox(
              value: isAllDay,
              onChanged: (bool? value) {
                setState(() {
                  isAllDay = value ?? false;
                });
              },
            ),
            const Text('All day'),
          ],
        ),

        const SizedBox(height: 20),

        Text('Start Date & Time', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(
          height: 120,
          child: DateTimePickerExample(
            onDateTimeChanged: (DateTime startDateTime) {
              setState(() {
                selectedStartDateTime = startDateTime;
              });
            },
          ),
        ),

        const SizedBox(height: 20),

        Text('End Date & Time', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(
          height: 120,
          child: DateTimePickerExample(
            onDateTimeChanged: (DateTime endDateTime) {
              setState(() {
                selectedEndDateTime = endDateTime;
              });
            },
          ),
        ),

        const SizedBox(height: 30),

        Center(
          child: ElevatedButton(
            onPressed: () {
              print(selectedColorIndex);
              final result = {
                'subject': _subjectController.text,
                'notes': _notesController.text,
                'startDate': selectedStartDateTime,
                'endDate': selectedEndDateTime,
                'colorIndex': selectedColorIndex,
                'isAllDay': isAllDay,
              };
              Navigator.pop(context, result);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              child: Text('Save', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ],
    ),
  ),
);

  }
}
