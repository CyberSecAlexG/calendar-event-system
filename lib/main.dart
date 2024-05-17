import 'dart:ui';

import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

DateTime get _now => DateTime.now();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CalendarControllerProvider(
      controller: EventController(),
      child: MaterialApp(
        title: 'Flutter Calendar Page Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(),
        scrollBehavior: const ScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.trackpad,
            PointerDeviceKind.mouse,
            PointerDeviceKind.touch,
          },
        ),
        home: const CalendarPageView(),
      ),
    );
  }
}

class ExtendedCalendarEventData<T extends Object?> extends CalendarEventData<T> {
  final int id;

  ExtendedCalendarEventData({
    required this.id,
    required String title,
    required DateTime date,
    DateTime? startTime,
    DateTime? endTime,
    String? description,
    T? event,
    Color color = Colors.blue,
    TextStyle? titleStyle,
    TextStyle? descriptionStyle,
    DateTime? endDate,
  }) : super(
          title: title,
          date: date,
          startTime: startTime,
          endTime: endTime,
          description: description,
          event: event,
          color: color,
          titleStyle: titleStyle,
          descriptionStyle: descriptionStyle,
          endDate: endDate,
        );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'title': title,
      'description': description,
      'color': color.value,
      'event': event.toString(),
    };
  }

  factory ExtendedCalendarEventData.fromMap(Map<String, dynamic> map) {
    return ExtendedCalendarEventData(
      id: map['id'],
      title: map['title'],
      date: DateTime.parse(map['date']),
      startTime: map['startTime'] != null ? DateTime.parse(map['startTime']) : null,
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      description: map['description'],
      color: Color(map['color']),
      event: map['event'],
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'events.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        startTime TEXT,
        endTime TEXT,
        title TEXT,
        description TEXT,
        color INTEGER,
        event TEXT
      )
    ''');
  }

  Future<int> insertEvent(ExtendedCalendarEventData event) async {
    Database db = await database;
    return await db.insert('events', event.toMap());
  }

  Future<List<ExtendedCalendarEventData>> getEvents() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('events');
    return List.generate(maps.length, (i) {
      return ExtendedCalendarEventData.fromMap(maps[i]);
    });
  }

  Future<int> updateEvent(ExtendedCalendarEventData event) async {
    Database db = await database;
    return await db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<int> deleteEvent(int id) async {
    Database db = await database;
    return await db.delete(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class EventManager {
  final EventController<ExtendedCalendarEventData> _eventController = EventController();

  EventManager() {
    _loadEventsFromDatabase();
  }

  EventController<ExtendedCalendarEventData> get eventController => _eventController;

  Future<void> _loadEventsFromDatabase() async {
    List<ExtendedCalendarEventData> events = await DatabaseHelper().getEvents();
    _eventController.addAll(events.cast<CalendarEventData<ExtendedCalendarEventData<Object?>>>());
  }

  Future<void> addEvent(ExtendedCalendarEventData event) async {
    await DatabaseHelper().insertEvent(event);
    _eventController.add(event as CalendarEventData<ExtendedCalendarEventData<Object?>>);
  }

  Future<void> updateEvent(ExtendedCalendarEventData oldEvent, ExtendedCalendarEventData newEvent) async {
    await DatabaseHelper().updateEvent(newEvent);
    _eventController.update(oldEvent as CalendarEventData<ExtendedCalendarEventData<Object?>>, newEvent as CalendarEventData<ExtendedCalendarEventData<Object?>>);
  }

  Future<void> deleteEvent(ExtendedCalendarEventData event) async {
    await DatabaseHelper().deleteEvent(event.id);
    _eventController.remove(event as CalendarEventData<ExtendedCalendarEventData<Object?>>);
  }
}

class CalendarPageView extends StatefulWidget {
  const CalendarPageView({super.key});

  @override
  _CalenderPageViewState createState() => _CalenderPageViewState();
}

class _CalenderPageViewState extends State<CalendarPageView> {
  int _selectedIndex = 0;
  static const List<Widget> _widgetOptions = <Widget>[
    MonthViewPage(),
    WeekViewPage(),
    DayViewPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Month',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_week),
            label: 'Week',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.today),
            label: 'Day',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => EventViewPage()),);
        },
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        tooltip: "Add Event",
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class MonthViewPage extends StatelessWidget {
  const MonthViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MonthView(
        minMonth: DateTime(1990),
        maxMonth: DateTime(2050),
        initialMonth: DateTime.now(),
        onCellTap: (events, date) {
          print(date);
        },
        onEventTap: (events, date) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EventDetailsPage(event: events),
            ),
          );
        },
      ),
    );
  }
}

class DayViewPage extends StatelessWidget {
  const DayViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DayView(
        onEventTap: (events, date) {
          if (events.isNotEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EventDetailsPage(event: events[0]),
              ),
            );
          }
        },
      ),
    );
  }
}

class WeekViewPage extends StatelessWidget {
  const WeekViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WeekView(
        onEventTap: (events, date) {
          if (events.isNotEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EventDetailsPage(event: events[0]),
              ),
            );
          }
        },
      ),
    );
  }
}

class EventViewPage extends StatefulWidget {
  final CalendarEventData? event;

  const EventViewPage({super.key, this.event});

  @override
  EventViewPageState createState() => EventViewPageState();
}

class EventViewPageState extends State<EventViewPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TextEditingController eventNameCtl = TextEditingController();
  TextEditingController dateCtl = TextEditingController();
  TextEditingController startTimeCtl = TextEditingController();
  TextEditingController endTimeCtl = TextEditingController();
  TextEditingController descriptionCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      eventNameCtl.text = widget.event!.title;
      dateCtl.text = formatDate(widget.event!.date);
      startTimeCtl.text = formatTimeOfDay(TimeOfDay.fromDateTime(widget.event!.startTime!));
      endTimeCtl.text = formatTimeOfDay(TimeOfDay.fromDateTime(widget.event!.endTime!));
      descriptionCtl.text = widget.event!.description ?? '';
    }
  }

  String formatDate(DateTime date) {
    final DateFormat formatter = DateFormat('dd/MM/yyyy');
    return formatter.format(date);
  }

  String formatTimeOfDay(TimeOfDay timeOfDay) {
    final now = DateTime.now();
    final DateTime dateTime = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
    final DateFormat formatter = DateFormat('HH:mm');
    return formatter.format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null ? "Create New Event" : "Edit Event"),
      ),
      body: Padding(
        padding: EdgeInsets.all(width * 0.03),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: eventNameCtl,
                decoration: const InputDecoration(
                  labelText: 'Event Title',
                  border: OutlineInputBorder(),
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
              SizedBox(height: height * 0.02),
              TextFormField(
                controller: dateCtl,
                decoration: const InputDecoration(
                  labelText: 'Select Date',
                  border: OutlineInputBorder(),
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please choose a date';
                  }
                  return null;
                },
                onTap: () async {
                  FocusScope.of(context).requestFocus(FocusNode());
                  DateTime? setDate = await showDatePicker(
                    context: context,
                    firstDate: DateTime(1990),
                    lastDate: DateTime(2050),
                    initialDate: DateTime.now(),
                  );
                  if (setDate != null) {
                    dateCtl.text = formatDate(setDate);
                  }
                },
              ),
              SizedBox(height: height * 0.02),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: startTimeCtl,
                      decoration: const InputDecoration(
                        labelText: 'Start Time',
                        border: OutlineInputBorder(),
                      ),
                      onTap: () async {
                        FocusScope.of(context).requestFocus(FocusNode());
                        TimeOfDay? setTime = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 0, minute: 0),
                        );
                        if (setTime != null) {
                          startTimeCtl.text = formatTimeOfDay(setTime);
                        }
                      },
                    ),
                  ),
                  SizedBox(width: width * 0.05),
                  Expanded(
                    child: TextFormField(
                      controller: endTimeCtl,
                      decoration: const InputDecoration(
                        labelText: 'End Time',
                        border: OutlineInputBorder(),
                      ),
                      onTap: () async {
                        FocusScope.of(context).requestFocus(FocusNode());
                        TimeOfDay? setTime = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 0, minute: 0),
                        );
                        if (setTime != null) {
                          endTimeCtl.text = formatTimeOfDay(setTime);
                        }
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: height * 0.02),
              TextFormField(
                controller: descriptionCtl,
                decoration: const InputDecoration(
                  labelText: 'Event Description',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: height * 0.02),
              SizedBox(
                width: width * 0.5,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      DateTime now = DateTime.now();
                      List<String> startTimeParts = startTimeCtl.text.split(':');
                      List<String> endTimeParts = endTimeCtl.text.split(':');
                      int startHour = int.parse(startTimeParts[0]);
                      int endHour = int.parse(endTimeParts[0]);
                      int startMin = int.parse(startTimeParts[1]);
                      int endMin = int.parse(endTimeParts[1]);
                      DateTime startTime = DateTime(now.year, now.month, now.day, startHour, startMin);
                      DateTime endTime = DateTime(now.year, now.month, now.day, endHour, endMin);

                      final newEvent = CalendarEventData(
                        title: eventNameCtl.text,
                        date: DateFormat('dd/MM/yyyy').parseStrict(dateCtl.text),
                        startTime: startTime,
                        endTime: endTime,
                        description: descriptionCtl.text,
                      );

                      if (widget.event != null) {
                        CalendarControllerProvider.of(context).controller.update(widget.event!, newEvent);
                      } else {
                        CalendarControllerProvider.of(context).controller.add(newEvent);
                      }

                      Navigator.of(context).pop(true);
                    }
                  },
                  child: Text(widget.event == null ? 'Create' : 'Update'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EventDetailsPage extends StatelessWidget {
  final CalendarEventData event;

  const EventDetailsPage({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: event.color,
        elevation: 0,
        centerTitle: false,
        title: Text(
          event.title,
          style: TextStyle(
            color: event.color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back,
            color: event.color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Date: ${event.date.day}/${event.date.month}/${event.date.year}",
              style: TextStyle(fontSize: 16.0),
            ),
            SizedBox(height: 15.0),
            if (event.startTime != null && event.endTime != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("From"),
                        Text(
                          "${event.startTime!.hour}:${event.startTime!.minute.toString().padLeft(2, '0')}",
                          style: TextStyle(fontSize: 16.0),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("To"),
                        Text(
                          "${event.endTime!.hour}:${event.endTime!.minute.toString().padLeft(2, '0')}",
                          style: TextStyle(fontSize: 16.0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30.0),
            ],
            if (event.description?.isNotEmpty ?? false) ...[
              Divider(),
              Text("Description"),
              SizedBox(height: 10.0),
              Text(event.description!),
            ],
            Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      CalendarControllerProvider.of(context).controller.remove(event);
                      Navigator.of(context).pop();
                    },
                    child: Text('Delete Event'),
                  ),
                ),
                SizedBox(width: 30),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EventViewPage(event: event),
                        ),
                      );

                      if (result == true) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text('Edit Event'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}