// 사용자 지정 파일 번호 규칙을 따른다.
// ignore_for_file: file_names

import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_routine/data/services/calendar_service.dart';

class _Plugin implements DeviceCalendar {
  final calls = <Invocation>[];
  Event? event;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    if (invocation.memberName == #createEvent) return Future.value('id');
    if (invocation.memberName == #getEvent) return Future<Event?>.value(event);
    if (invocation.memberName == #updateEvent) return Future<void>.value();
    throw UnsupportedError('${invocation.memberName}');
  }
}

void main() {
  test('새 시간 일정은 자정을 넘어도 60분이며 종일 일정은 다음 날 종료', () async {
    final p = _Plugin();
    final s = CalendarService(plugin: p);
    await s.create(
      calendarId: 'c',
      title: '일정',
      day: DateTime(2026, 10, 20),
      time: '23:30',
    );
    var args = p.calls.last.namedArguments;
    expect(args[#startDate], DateTime(2026, 10, 20, 23, 30));
    expect(args[#endDate], DateTime(2026, 10, 21, 0, 30));
    expect(args[#isAllDay], false);
    await s.create(calendarId: 'c', title: '일정', day: DateTime(2026, 10, 20));
    args = p.calls.last.namedArguments;
    expect(args[#isAllDay], true);
    expect(args[#endDate], DateTime(2026, 10, 21));
  });

  test('외부 시간 일정 이동은 길이를 보존하고 시간대와 기타 메타데이터는 수정하지 않는다', () async {
    final p = _Plugin()
      ..event = Event(
        eventId: 'id',
        instanceId: 'id',
        availability: EventAvailability.busy,
        status: EventStatus.confirmed,
        isRecurring: false,
        calendarId: 'c',
        title: '원본',
        isAllDay: false,
        startDate: DateTime(2026, 10, 20, 23, 30),
        endDate: DateTime(2026, 10, 21, 2),
        timeZone: 'Asia/Seoul',
        description: '메모',
        location: '장소',
      );
    final s = CalendarService(plugin: p);
    await s.update(eventId: 'id', day: DateTime(2026, 10, 22), time: '22:00');
    final args = p.calls.last.namedArguments;
    expect(args[#startDate], DateTime(2026, 10, 22, 22));
    expect(args[#endDate], DateTime(2026, 10, 23, 0, 30));
    expect(args[#timeZone], isNull);
    expect(args[#description], isNull);
    expect(args[#location], isNull);
    expect(args[#reminders], isNull);
  });

  test('시간 삭제는 종일로 전환하고 제목만 수정하면 일정을 읽거나 변경하지 않는다', () async {
    final p = _Plugin()
      ..event = Event(
        eventId: 'id',
        instanceId: 'id',
        availability: EventAvailability.busy,
        status: EventStatus.confirmed,
        isRecurring: false,
        calendarId: 'c',
        title: '원본',
        isAllDay: false,
        startDate: DateTime(2026, 10, 20, 14),
        endDate: DateTime(2026, 10, 20, 15),
      );
    final s = CalendarService(plugin: p);
    await s.update(eventId: 'id', time: '');
    var args = p.calls.last.namedArguments;
    expect(args[#startDate], DateTime(2026, 10, 20));
    expect(args[#endDate], DateTime(2026, 10, 21));
    expect(args[#isAllDay], true);
    p.calls.clear();
    await s.update(eventId: 'id', title: '수정');
    expect(p.calls.length, 1);
    args = p.calls.single.namedArguments;
    expect(args[#startDate], isNull);
    expect(args[#endDate], isNull);
    expect(args[#isAllDay], isNull);
  });

  test('종일에서 시간 지정 시 기본 길이와 잘못된 시각 검증', () async {
    final p = _Plugin()
      ..event = Event(
        eventId: 'id',
        instanceId: 'id',
        availability: EventAvailability.busy,
        status: EventStatus.confirmed,
        isRecurring: false,
        calendarId: 'c',
        title: '원본',
        isAllDay: true,
        startDate: DateTime(2026, 10, 20),
        endDate: DateTime(2026, 10, 23),
      );
    final s = CalendarService(plugin: p);
    await s.update(eventId: 'id', time: '14:30');
    expect(
      p.calls.last.namedArguments[#endDate],
      DateTime(2026, 10, 20, 15, 30),
    );
    expect(
      () => s.create(
        calendarId: 'c',
        title: '일정',
        day: DateTime(2026),
        time: '25:00',
      ),
      throwsFormatException,
    );
  });
}
