import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:gss/mainpages/event.dart';
import 'package:gss/services/DBservice.dart';
import 'package:table_calendar/table_calendar.dart';

class Calendar extends StatefulWidget {
  final String clubName; // club 이름 저장

  const Calendar({super.key, required this.clubName});

  @override
  State<Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  @override
  bool _isLoading = true;
  Map<DateTime, List<String>> _events = {};
  DateTime _focusedDay = DateTime.now();
  DateTime _firstDay = DateTime.utc(2025, 08, 01);
  DateTime _lastDay = DateTime.utc(2025, 12, 31);
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime? _selectedDay;
  TextEditingController _eventController = TextEditingController();
  late final ValueNotifier<List<Event>> _selectedEvents;
  List<Event> _getEventsForDay(DateTime day) {
    return events[day] ?? [];
  }

  Map<DateTime, List<Event>> events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _fetchAllEvents(widget.clubName).then((_) {
      setState(() {
        _isLoading = false; // 데이터 로딩 완료 표시
      });
    });
  }

  Future<void> _fetchAndSetEvents(DateTime day) async {
    String formattedDate =
        "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";

    final loadedEvents = await DBsvc().loadEvents(widget.clubName, formattedDate);

    setState(() {
      events[day] = loadedEvents;
    });

    _selectedEvents.value = loadedEvents;
  }

  Future<void> _fetchAllEvents(String club) async {
    final snapshot = await FirebaseDatabase.instance
        .ref("Club/$club/Calendar")
        .get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;

      data.forEach((dateStr, value) {
        DateTime date = DateTime.parse(dateStr);
        List<Event> eventList = [];

        if (value is List) {
          eventList = value.map((e) => Event(e.toString())).toList();
        } else if (value is Map) {
          eventList = value.values.map((e) => Event(e.toString())).toList();
        }

        events[DateTime.utc(date.year, date.month, date.day)] = eventList;
      });
    }
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                scrollable: true,
                title: Text("Event Name"),
                content: Padding(
                  padding: EdgeInsets.all(8),
                  child: TextField(controller: _eventController),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      events.addAll({
                        _selectedDay!: [Event(_eventController.text)],
                      });
                      Navigator.of(context).pop();
                      _selectedEvents.value = _getEventsForDay(_selectedDay!);
                      DBsvc().DBcalendar(
                        _selectedDay!,
                        widget.clubName,
                        _eventController.text,
                      );
                    },
                    child: Text("Submit"),
                  ),
                ],
              );
            },
          );
        },
        child: Icon(Icons.add),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: _firstDay,
            lastDay: _lastDay,
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              // Use `selectedDayPredicate` to determine which day is currently selected.
              // If this returns true, then `day` will be marked as selected.

              // Using `isSameDay` is recommended to disregard
              // the time-part of compared DateTime objects.
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                // Call `setState()` when updating the selected day
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  //_selectedEvents.value = _getEventsForDay(selectedDay);
                });
                _fetchAndSetEvents(selectedDay);
              }
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                // Call `setState()` when updating calendar format
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              // No need to call `setState()` here
              _focusedDay = focusedDay;
            },
            eventLoader: (day) {
              return _getEventsForDay(day);
            },
          ),
          SizedBox(height: 10),
          Expanded(
            child: ValueListenableBuilder<List<Event>>(
              valueListenable: _selectedEvents,
              builder: (context, value, _) {
                if (value.isEmpty) {
                  return const Center(child: Text('이 날짜에는 이벤트가 없습니다.'));
                }
                return ListView.builder(
                  itemCount: value.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        onTap: () => print(value[index].title),
                        title: Text(value[index].title),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}