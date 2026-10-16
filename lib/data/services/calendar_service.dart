import 'package:device_calendar_plus/device_calendar_plus.dart';

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

  /// 종일 이벤트를 만들고 이벤트 ID를 돌려준다. 종일 이벤트의 끝 날짜는 다음 날 0시다.
  Future<String> create({required String calendarId, required String title, required DateTime day}) {
    final start = DateTime(day.year, day.month, day.day);
    return _plugin.createEvent(
      calendarId: calendarId,
      title: title,
      startDate: start,
      endDate: DateTime(day.year, day.month, day.day + 1),
      isAllDay: true,
      description: 'TDnR 투두',
    );
  }

  /// 이벤트가 이미 지워졌으면 false.
  Future<bool> update({required String eventId, required String title, required DateTime day}) async {
    try {
      await _plugin.updateEvent(
        instanceId: eventId,
        title: title,
        startDate: DateTime(day.year, day.month, day.day),
        endDate: DateTime(day.year, day.month, day.day + 1),
        isAllDay: true,
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
