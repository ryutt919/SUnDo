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
    this.calendarId = '',
    this.start,
    this.end,
    this.timeZone,
  });

  final DateTime? start;
  final DateTime? end;
  final String? timeZone;

  final String id;
  final String title;
  final DateTime day; // 시작 날짜(시각 없음)
  final bool allDay;
  final bool recurring;
  final String time; // 종일이 아닌 일정의 시작 시각 'HH:mm', 종일이면 빈 문자열
  final String calendarId; // 이 일정이 들어 있는 캘린더
}

/// 기기 캘린더(Android CalendarProvider)를 감싼 서비스. 상태는 가지지 않는다.
/// 삼성 캘린더나 구글 캘린더 계정에 연결된 캘린더에 쓰면 해당 계정으로 동기화된다.
class CalendarService {
  CalendarService({DeviceCalendar? plugin})
    : _plugin = plugin ?? DeviceCalendar.instance;

  final DeviceCalendar _plugin;

  Future<bool> hasPermission() async =>
      await _plugin.hasPermissions() == CalendarPermissionStatus.granted;

  Future<bool> requestPermission() async =>
      await _plugin.requestPermissions() == CalendarPermissionStatus.granted;

  /// 쓸 수 있는 캘린더(읽기 전용과 숨김은 제외).
  Future<List<Calendar>> writableCalendars() async {
    final all = await _plugin.listCalendars();
    return [
      for (final c in all)
        if (!c.readOnly && !c.hidden) c,
    ];
  }

  /// 가져올 캘린더를 고르는 데 쓰는 목록: 숨기지 않은 모든 캘린더(공휴일 같은 읽기 전용 포함).
  Future<List<Calendar>> visibleCalendars() async {
    final all = await _plugin.listCalendars();
    return [
      for (final c in all)
        if (!c.hidden) c,
    ];
  }

  static CalendarEvent _convert(Event e, {String? id}) => CalendarEvent(
    id: id ?? e.instanceId,
    title: e.title,
    day: DateTime(e.startDate.year, e.startDate.month, e.startDate.day),
    allDay: e.isAllDay,
    recurring: e.isRecurring,
    calendarId: e.calendarId,
    start: e.startDate,
    end: e.endDate,
    timeZone: e.timeZone,
    time: e.isAllDay
        ? ''
        : '${e.startDate.hour.toString().padLeft(2, '0')}:${e.startDate.minute.toString().padLeft(2, '0')}',
  );

  /// 이벤트 하나를 읽는다. 지워졌으면 null.
  Future<CalendarEvent?> get(String eventId) async {
    final e = await _plugin.getEvent(eventId);
    return e == null ? null : _convert(e, id: eventId);
  }

  /// [calendarIds]의 캘린더들에서 [from] 이상 [to] 미만에 걸친 이벤트(반복 일정은 회차마다 한 개).
  Future<List<CalendarEvent>> listBetween({
    required List<String> calendarIds,
    required DateTime from,
    required DateTime to,
  }) async {
    if (calendarIds.isEmpty) return const [];
    final events = await _plugin.listEvents(from, to, calendarIds: calendarIds);
    return [for (final e in events) _convert(e)];
  }

  static DateTime _start(DateTime day, String time) {
    if (time.isEmpty) return DateTime(day.year, day.month, day.day);
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(time);
    if (match == null) throw FormatException('올바르지 않은 일정 시각');
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    if (hour > 23 || minute > 59) throw FormatException('올바르지 않은 일정 시각');
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  /// 시간이 있는 새 일정은 기본 60분이다.
  Future<String> create({
    required String calendarId,
    required String title,
    required DateTime day,
    String time = '',
  }) {
    final start = _start(day, time);
    return _plugin.createEvent(
      calendarId: calendarId,
      title: title,
      startDate: start,
      endDate: time.isEmpty
          ? DateTime(day.year, day.month, day.day + 1)
          : start.add(const Duration(hours: 1)),
      isAllDay: time.isEmpty,
      description: '루티닝 투두',
    );
  }

  /// 시각 null은 유지, 빈 문자열은 종일 전환이다. 기존 시간 일정의 길이는 유지한다.
  /// 지정하지 않은 메타데이터와 시간대는 플러그인의 부분 수정 계약에 따라 유지한다.
  Future<bool> update({
    required String eventId,
    String? title,
    DateTime? day,
    String? time,
  }) async {
    try {
      DateTime? start;
      DateTime? end;
      bool? allDay;
      if (day != null || time != null) {
        final existing = await _plugin.getEvent(eventId);
        if (existing == null) return false;
        final targetDay = day ?? existing.startDate;
        final targetTime =
            time ??
            (existing.isAllDay
                ? ''
                : '${existing.startDate.hour.toString().padLeft(2, '0')}:${existing.startDate.minute.toString().padLeft(2, '0')}');
        allDay = targetTime.isEmpty;
        start = _start(targetDay, targetTime);
        if (allDay) {
          final days = existing.isAllDay
              ? DateTime.utc(
                      existing.endDate.year,
                      existing.endDate.month,
                      existing.endDate.day,
                    )
                    .difference(
                      DateTime.utc(
                        existing.startDate.year,
                        existing.startDate.month,
                        existing.startDate.day,
                      ),
                    )
                    .inDays
              : 1;
          end = DateTime(
            start.year,
            start.month,
            start.day + (days > 0 ? days : 1),
          );
        } else {
          final duration = existing.isAllDay
              ? const Duration(hours: 1)
              : existing.endDate.difference(existing.startDate);
          if (duration < Duration.zero) throw StateError('일정 종료가 시작보다 늦지 않음');
          end = start.add(duration);
        }
      }
      await _plugin.updateEvent(
        instanceId: eventId,
        title: title,
        startDate: start,
        endDate: end,
        isAllDay: allDay,
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
