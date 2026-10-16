import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_routine/data/repositories/calendar_repository.dart';
import 'package:my_routine/data/services/calendar_service.dart';
import 'package:my_routine/data/services/storage_service.dart';
import 'package:my_routine/domain/models/journal_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 기기 캘린더 대신 만든 이벤트를 메모리에 들고 있는 가짜 서비스.
class _FakeCalendar implements CalendarService {
  bool permission = true;
  int nextId = 1;
  final Map<String, ({String title, DateTime day})> events = {};
  final List<String> log = [];

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<List<Calendar>> writableCalendars() async => [];

  @override
  Future<String> create({required String calendarId, required String title, required DateTime day}) async {
    final id = 'e${nextId++}';
    events[id] = (title: title, day: day);
    log.add('create $id');
    return id;
  }

  @override
  Future<bool> update({required String eventId, required String title, required DateTime day}) async {
    if (!events.containsKey(eventId)) return false;
    events[eventId] = (title: title, day: day);
    log.add('update $eventId');
    return true;
  }

  @override
  Future<void> delete(String eventId) async {
    events.remove(eventId);
    log.add('delete $eventId');
  }
}

const _cal = CalendarChoice(id: 'c1', name: '개인', account: 'me@example.com', isPrimary: true);

Future<({CalendarRepository repo, _FakeCalendar fake})> _setup() async {
  SharedPreferences.setMockInitialValues({});
  final store = await StorageService.create();
  final fake = _FakeCalendar();
  final repo = CalendarRepository(store, fake);
  await repo.load();
  return (repo: repo, fake: fake);
}

Todo _todo(String id, String text, String date, {bool done = false}) => Todo(id: id, text: text, date: date, done: done);

void main() {
  test('연동을 켜기 전에는 캘린더를 건드리지 않는다', () async {
    final s = await _setup();
    await s.repo.sync([_todo('a', '병원', '2026-10-20')]);
    expect(s.fake.events, isEmpty);
  });

  test('투두를 종일 일정으로 만들고, 바뀐 것만 고치고, 사라진 투두의 일정은 지운다', () async {
    final s = await _setup();
    await s.repo.enable(_cal);
    await s.repo.sync([_todo('a', '병원', '2026-10-20')]);
    expect(s.fake.events.length, 1);
    expect(s.fake.events.values.single.title, '병원');
    expect(s.fake.events.values.single.day, DateTime(2026, 10, 20));

    s.fake.log.clear();
    await s.repo.sync([_todo('a', '병원', '2026-10-20')]);
    expect(s.fake.log, isEmpty, reason: '변화가 없으면 아무것도 하지 않는다');

    await s.repo.sync([_todo('a', '병원', '2026-10-22', done: true)]);
    expect(s.fake.log, ['update e1']);
    expect(s.fake.events['e1']!.title, '✔ 병원');
    expect(s.fake.events['e1']!.day, DateTime(2026, 10, 22));

    await s.repo.sync([]);
    expect(s.fake.events, isEmpty, reason: '투두를 지우면 일정도 지운다');
    expect(s.repo.linkedCount, 0);
  });

  test('캘린더에서 지워진 일정은 다음 동기화에서 다시 만든다', () async {
    final s = await _setup();
    await s.repo.enable(_cal);
    await s.repo.sync([_todo('a', '회의', '2026-10-20')]);
    s.fake.events.clear(); // 사용자가 캘린더 앱에서 직접 지움
    await s.repo.sync([_todo('a', '회의 수정', '2026-10-20')]);
    expect(s.fake.events.values.single.title, '회의 수정');
  });

  test('다른 캘린더로 바꾸면 이전 일정을 지우고 새 캘린더에 만든다', () async {
    final s = await _setup();
    await s.repo.enable(_cal);
    await s.repo.sync([_todo('a', '회의', '2026-10-20')]);
    await s.repo.enable(const CalendarChoice(id: 'c2', name: '업무', account: '', isPrimary: false));
    await s.repo.sync([_todo('a', '회의', '2026-10-20')]);
    expect(s.fake.events.length, 1);
    expect(s.fake.log, ['create e1', 'delete e1', 'create e2']);
  });

  test('권한이 없으면 동기화하지 않고, 연동 설정은 다시 읽어도 유지된다', () async {
    final s = await _setup();
    await s.repo.enable(_cal);
    s.fake.permission = false;
    await s.repo.sync([_todo('a', '회의', '2026-10-20')]);
    expect(s.fake.events, isEmpty);

    s.fake.permission = true;
    await s.repo.sync([_todo('a', '회의', '2026-10-20')]);
    final again = CalendarRepository(await StorageService.create(), s.fake);
    await again.load();
    expect(again.enabled, isTrue);
    expect(again.calendarName, '개인');
    expect(again.linkedCount, 1);
  });

  test('연동을 끄면 일정은 남기고, 모두 지우기를 누르면 일정과 기록을 지운다', () async {
    final s = await _setup();
    await s.repo.enable(_cal);
    await s.repo.sync([_todo('a', '회의', '2026-10-20')]);
    await s.repo.disable();
    await s.repo.sync([]);
    expect(s.fake.events.length, 1, reason: '꺼진 동안에는 건드리지 않는다');
    await s.repo.removeAllEvents();
    expect(s.fake.events, isEmpty);
    expect(s.repo.linkedCount, 0);
  });
}
