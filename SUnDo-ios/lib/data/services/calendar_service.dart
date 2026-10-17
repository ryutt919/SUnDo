import 'package:device_calendar_plus/device_calendar_plus.dart';

/// 캘린더에서 읽어 온 이벤트 한 개. 시작 날짜와, 종일이 아니면 시작 시각('HH:mm')만 쓴다.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.day,
    required this.allDay,
    required this.recurring,
    this.time = '',
  });

  final String id;
  final String title;
  final DateTime day; // 시작 날짜(시각 없음)
  final bool allDay;
  final bool recurring;
  final String time; // 종일이 아닌 일정의 시작 시각 'HH:mm', 종일이면 빈 문자열
}

/// 기기 캘린더(Android CalendarProvider)를 감싼 서비스. 상태는 가지지 않는다.
/// 삼성 캘린더나 구글 캘린더 계정에 연결된 캘린더에 쓰면 해당 계정으로 동기화된다.
class CalendarService {
  CalendarService({DeviceCalendar? plugin}) : _plugin = plugin ?? DeviceCalendar.instance;

  final DeviceCalendar _plugin;

  Future<bool> hasPermission() async => await _plugin.hasPermissions() == CalendarPermissionStatus.granted;

  Future<bool> requestPermission() async => await _plugin.requestPermissions() == CalendarPermissionStatus.granted;

  /// 쓸 수 있는 캘린더(읽기 전용과 숨김은 제외).
  Future<List<Calendar>> writableCalendars() async {
    final all = await _plugin.listCalendars();
    return [
      for (final c in all)
        if (!c.readOnly && !c.hidden) c
    ];
  }

  static CalendarEvent _convert(Event e, {String? id}) => CalendarEvent(
        id: id ?? e.instanceId,
        title: e.title,
        day: DateTime(e.startDate.year, e.startDate.month, e.startDate.day),
        allDay: e.isAllDay,
        recurring: e.isRecurring,
        time: e.isAllDay ? '' : '${e.startDate.hour.toString().padLeft(2, '0')}:${e.startDate.minute.toString().padLeft(2, '0')}',
      );

  /// 이벤트 하나를 읽는다. 지워졌으면 null.
  Future<CalendarEvent?> get(String eventId) async {
    final e = await _plugin.getEvent(eventId);
    return e == null ? null : _convert(e, id: eventId);
  }

  /// [calendarId]에서 [from] 이상 [to] 미만에 걸친 이벤트(반복 일정은 회차마다 한 개).
  Future<List<CalendarEvent>> listBetween({required String calendarId, required DateTime from, required DateTime to}) async {
    final events = await _plugin.listEvents(from, to, calendarIds: [calendarId]);
    return [for (final e in events) _convert(e)];
  }

  /// 종일 이벤트를 만들고 이벤트 ID를 돌려준다. 종일 이벤트의 끝 날짜는 다음 날 0시다.
  Future<String> create({required String calendarId, required String title, required DateTime day}) {
    final start = DateTime(day.year, day.month, day.day);
    return _plugin.createEvent(
      calendarId: calendarId,
      title: title,
      startDate: start,
      endDate: DateTime(day.year, day.month, day.day + 1),
      isAllDay: true,
      description: '루티닝 투두',
    );
  }

  /// [title]을 주면 제목을, [day]를 주면 그 날의 종일 이벤트로 옮긴다. 주지 않은 것은 그대로 둔다.
  /// 이벤트가 이미 지워졌으면 false.
  Future<bool> update({required String eventId, String? title, DateTime? day}) async {
    try {
      await _plugin.updateEvent(
        instanceId: eventId,
        title: title,
        startDate: day == null ? null : DateTime(day.year, day.month, day.day),
        endDate: day == null ? null : DateTime(day.year, day.month, day.day + 1),
        isAllDay: day == null ? null : true,
      );
      return true;
    } on DeviceCalendarException catch (e) {
      if (e.errorCode == DeviceCalendarError.notFound) return false;
      rethrow;
    }
  }

  /// 이미 없는 이벤트를 지우려 해도 오류로 보지 않는다.
  Future<void> delete(String eventId) async {
    try {
      await _plugin.deleteEvent(instanceId: eventId);
    } on DeviceCalendarException catch (e) {
      if (e.errorCode != DeviceCalendarError.notFound) rethrow;
    }
  }
}
