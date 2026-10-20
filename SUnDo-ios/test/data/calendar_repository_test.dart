import 'dart:async';

import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_routine/data/repositories/calendar_repository.dart';
import 'package:my_routine/data/repositories/journal_repository.dart';
import 'package:my_routine/data/services/calendar_service.dart';
import 'package:my_routine/data/services/storage_service.dart';
import 'package:my_routine/domain/models/date_key.dart';
import 'package:my_routine/domain/models/journal_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Ev {
  _Ev(
    this.title,
    this.day, {
    this.recurring = false,
    this.time = '',
    this.calendarId = 'c1',
  });
  String title;
  DateTime day;
  bool allDay = true;
  bool recurring;
  String time;
  String calendarId;
}

/// 기기 캘린더 대신 이벤트를 메모리에 들고 있는 가짜 서비스.
class _FakeCalendar implements CalendarService {
  bool permission = true;
  int nextId = 1;
  String? failCreateTitle;
  Completer<void>? readGate;
  Completer<void>? readStarted;
  final Map<String, _Ev> events = {};
  final List<String> log = [];

  /// 기기에 있는 캘린더들. 개인(c1)은 연동 대상, 업무(c2)는 다른 쓰기 가능 캘린더, 공휴일(c3)은 읽기 전용.
  final List<Calendar> calendars = const [
    Calendar(id: 'c1', name: '개인', readOnly: false, isPrimary: true),
    Calendar(id: 'c2', name: '업무', readOnly: false),
    Calendar(id: 'c3', name: '공휴일', readOnly: true),
    Calendar(id: 'c4', name: '숨김', readOnly: false, hidden: true),
  ];

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<List<Calendar>> writableCalendars() async => [
    for (final c in calendars)
      if (!c.readOnly && !c.hidden) c,
  ];

  @override
  Future<List<Calendar>> visibleCalendars() async => [
    for (final c in calendars)
      if (!c.hidden) c,
  ];

  @override
  Future<CalendarEvent?> get(String eventId) async {
    readStarted?.complete();
    readStarted = null;
    await readGate?.future;
    final e = events[eventId];
    return e == null
        ? null
        : CalendarEvent(
            id: eventId,
            title: e.title,
            day: e.day,
            allDay: e.allDay,
            recurring: e.recurring,
            time: e.time,
            calendarId: e.calendarId,
          );
  }

  @override
  Future<List<CalendarEvent>> listBetween({
    required List<String> calendarIds,
    required DateTime from,
    required DateTime to,
  }) async => [
    for (final entry in events.entries)
      if (calendarIds.contains(entry.value.calendarId) &&
          !entry.value.day.isBefore(from) &&
          entry.value.day.isBefore(to))
        CalendarEvent(
          id: entry.key,
          title: entry.value.title,
          day: entry.value.day,
          allDay: entry.value.allDay,
          recurring: entry.value.recurring,
          time: entry.value.time,
          calendarId: entry.value.calendarId,
        ),
  ];

  @override
  Future<String> create({
    required String calendarId,
    required String title,
    required DateTime day,
    String time = '',
  }) async {
    if (title == failCreateTitle) throw Exception('주입된 생성 실패');
    final id = 'e${nextId++}';
    events[id] = _Ev(title, day, time: time, calendarId: calendarId)
      ..allDay = time.isEmpty;
    log.add('create $id');
    return id;
  }

  @override
  Future<bool> update({
    required String eventId,
    String? title,
    DateTime? day,
    String? time,
  }) async {
    final e = events[eventId];
    if (e == null) return false;
    if (title != null) e.title = title;
    if (day != null) {
      e.day = day;
      e.allDay = (time ?? e.time).isEmpty;
    }
    if (time != null) {
      e.time = time;
      e.allDay = time.isEmpty;
    }
    log.add('update $eventId');
    return true;
  }

  @override
  Future<void> delete(String eventId) async {
    events.remove(eventId);
    log.add('delete $eventId');
  }
}

class _FailingStore extends StorageService {
  _FailingStore(super.prefs);
  int writes = 0;
  int? failAt;
  @override
  Future<void> writeJson(String key, Object value) async {
    if (key == 'calendar' && ++writes == failAt) {
      throw StorageWriteException(key);
    }
    await super.writeJson(key, value);
  }
}

const _cal = CalendarChoice(
  id: 'c1',
  name: '개인',
  account: 'me@example.com',
  isPrimary: true,
);

typedef _Setup = ({
  CalendarRepository repo,
  JournalRepository journal,
  _FakeCalendar fake,
});

Future<_Setup> _setup() async {
  SharedPreferences.setMockInitialValues({});
  final store = await StorageService.create();
  final journal = JournalRepository(store);
  await journal.load();
  final fake = _FakeCalendar();
  final repo = CalendarRepository(store, fake, journal);
  await repo.load();
  return (repo: repo, journal: journal, fake: fake);
}

Future<Todo> _addTodo(_Setup s, String text, String date) =>
    s.journal.addTodo(text, date);

Todo _todoOf(_Setup s, String id) =>
    s.journal.todos.firstWhere((t) => t.id == id);

String _future(int days) => addDaysKey(todayKey(), days);

void main() {
  test('결과 저장 실패를 성공 시각으로 기록하지 않으며 재시도는 성공한다', () async {
    SharedPreferences.setMockInitialValues({});
    final store = _FailingStore(await SharedPreferences.getInstance());
    final journal = JournalRepository(store);
    await journal.load();
    final repo = CalendarRepository(store, _FakeCalendar(), journal);
    await repo.enable(_cal);
    await repo.sync();
    final previousSuccessAt = repo.lastSuccessAt;
    store.writes = 0;
    store.failAt = 2;
    final failed = await repo.sync();
    expect(failed.status, CalendarSyncStatus.failure);
    expect(repo.lastSuccessAt, previousSuccessAt);
    store.failAt = null;
    expect((await repo.sync()).status, CalendarSyncStatus.success);
  });

  test('외부 삭제와 앱 수정 충돌은 앱 값을 보존해 새 일정으로 연결한다', () async {
    final s = await _setup();
    await s.repo.enable(_cal);
    final t = await s.journal.addTodo('회의', _future(1), time: '14:30');
    await s.repo.sync();
    s.fake.events.clear();
    await s.journal.patchTodo(t.id, time: '16:00');
    await s.repo.sync();
    expect(s.journal.todos.single.time, '16:00');
    expect(s.fake.events.values.single.time, '16:00');
    expect(s.repo.linkedCount, 1);
  });

  test('읽기 전용 오류 후 큐는 복구되고 성공 결과는 재시작 뒤에도 남는다', () async {
    final s = await _setup();
    await s.repo.enable(_cal);
    await s.repo.setImportCalendars({'c3'});
    s.fake.events['x'] = _Ev('공휴일', parseDateKey(_future(1)), calendarId: 'c3');
    await s.repo.sync();
    final t = s.journal.todos.single;
    await s.journal.patchTodo(t.id, time: '14:30');
    expect((await s.repo.sync()).status, CalendarSyncStatus.failure);
    await s.journal.patchTodo(t.id, time: '');
    expect((await s.repo.sync()).status, CalendarSyncStatus.success);
    final again = CalendarRepository(
      await StorageService.create(),
      s.fake,
      s.journal,
    );
    await again.load();
    expect(again.lastResult!.status, CalendarSyncStatus.success);
    expect(again.lastSuccessAt, s.repo.lastSuccessAt);
    await again.disable();
    expect(again.isTodoScheduleReadOnly(t.id), false);
  });

  test('시간 수정과 날짜 이동 및 시간 삭제가 같은 이벤트에 반영된다', () async {
    final s = await _setup();
    await s.repo.enable(_cal);
    final t = await s.journal.addTodo('회의', _future(1), time: '14:30');
    await s.repo.sync();
    await s.journal.patchTodo(t.id, date: _future(2), time: '16:00');
    await s.repo.sync();
    expect(s.fake.events['e1']!.time, '16:00');
    expect(dateKey(s.fake.events['e1']!.day), _future(2));
    await s.journal.patchTodo(t.id, time: '');
    await s.repo.sync();
    expect(s.fake.events['e1']!.allDay, true);
    expect(s.fake.events.length, 1);
  });

  test('앱 생성 일정도 외부 시각을 가져오고 동시 일정 변경은 앱이 이긴다', () async {
    final s = await _setup();
    await s.repo.enable(_cal);
    final t = await s.journal.addTodo('회의', _future(1), time: '14:30');
    await s.repo.sync();
    s.fake.events['e1']!
      ..time = '15:00'
      ..allDay = false;
    await s.repo.sync();
    expect(_todoOf(s, t.id).time, '15:00');
    await s.journal.patchTodo(t.id, time: '16:00');
    s.fake.events['e1']!
      ..time = '17:00'
      ..day = parseDateKey(_future(3));
    await s.repo.sync();
    expect(s.fake.events['e1']!.time, '16:00');
    expect(dateKey(s.fake.events['e1']!.day), _future(1));
    await s.repo.sync();
    expect(_todoOf(s, t.id).time, '16:00');
  });

  test('읽기 전용 일정에는 완료와 시각을 쓰지 않고 실패를 반환한다', () async {
    final s = await _setup();
    await s.repo.enable(_cal);
    await s.repo.setImportCalendars({'c3'});
    s.fake.events['x'] = _Ev('공휴일', parseDateKey(_future(1)), calendarId: 'c3');
    await s.repo.sync();
    final t = s.journal.todos.single;
    expect(s.repo.isTodoScheduleReadOnly(t.id), true);
    await s.journal.patchTodo(t.id, done: true, time: '14:00');
    final result = await s.repo.sync();
    expect(result.status, CalendarSyncStatus.failure);
    expect(result.failedCount, 1);
    expect(result.detail, contains('쓰기 권한'));
    expect(s.fake.log, isEmpty);
    expect(s.fake.events['x']!.time, '');
  });

  test('권한 부족과 부분 실패를 구분하고 재시도 후 성공 시각을 갱신한다', () async {
    final s = await _setup();
    expect((await s.repo.sync()).status, CalendarSyncStatus.disabled);
    await s.repo.enable(_cal);
    s.fake.permission = false;
    expect((await s.repo.sync()).status, CalendarSyncStatus.permissionDenied);
    expect(s.repo.lastSuccessAt, isNull);
    s.fake.permission = true;
    s.fake.failCreateTitle = '실패';
    await s.journal.addTodo('실패', _future(1));
    await s.journal.addTodo('정상', _future(1));
    final result = await s.repo.sync();
    expect(result.status, CalendarSyncStatus.partialFailure);
    expect(result.failedCount, 1);
    expect(result.processedCount, 1);
    s.fake.failCreateTitle = null;
    expect((await s.repo.sync()).status, CalendarSyncStatus.success);
    expect(s.repo.lastSuccessAt, isNotNull);
    expect(s.repo.isSyncing, false);
    expect(s.fake.events.length, 2);
  });

  test('기존 시간 기준이 없는 종일 링크는 같은 ID로 보정하고 가져오기 꺼짐을 유지한다', () async {
    final s = await _setup();
    final t = await s.journal.addTodo('회의', _future(1), time: '14:30');
    final store = await StorageService.create();
    await store.writeJson('calendar', {
      'schema': 2,
      'enabled': true,
      'calendarId': 'c1',
      'importNew': false,
      'links': {
        t.id: {
          'event': 'old',
          'calendar': 'c1',
          'title': '회의',
          'date': t.date,
          'imported': false,
        },
      },
    });
    s.fake.events['old'] = _Ev('회의', parseDateKey(t.date));
    await s.repo.load();
    await s.repo.sync();
    expect(s.fake.events.keys, ['old']);
    expect(s.fake.events['old']!.time, '14:30');
    expect(s.repo.importNew, false);
    await s.repo.sync();
    expect(s.fake.log, ['update old']);
  });

  test('기존 링크의 외부 일정도 바뀌었으면 추정 보정을 멈추고 실패로 남긴다', () async {
    final s = await _setup();
    final t = await s.journal.addTodo('회의', _future(1), time: '14:30');
    final store = await StorageService.create();
    await store.writeJson('calendar', {
      'schema': 2,
      'enabled': true,
      'calendarId': 'c1',
      'importNew': false,
      'links': {
        t.id: {
          'event': 'old',
          'calendar': 'c1',
          'title': '회의',
          'date': t.date,
          'imported': false,
        },
      },
    });
    s.fake.events['old'] = _Ev('회의', parseDateKey(_future(2)), time: '17:00')
      ..allDay = false;
    await s.repo.load();
    final result = await s.repo.sync();
    expect(result.status, CalendarSyncStatus.failure);
    expect(result.detail, contains('같은 값으로 맞춰'));
    expect(result.detail, isNot(contains('회의')));
    expect(s.fake.log, isEmpty);
    expect(_todoOf(s, t.id).time, '14:30');
  });

  test('기기 읽기 대기 중 앱 편집과 삭제를 덮거나 되살리지 않는다', () async {
    final s = await _setup();
    await s.repo.enable(_cal);
    final t = await s.journal.addTodo('회의', _future(1), time: '14:30');
    await s.repo.sync();
    s.fake.events['e1']!.time = '15:00';
    s.fake.readGate = Completer<void>();
    final started = s.fake.readStarted = Completer<void>();
    final syncing = s.repo.sync();
    await started.future;
    await s.journal.patchTodo(t.id, time: '16:00');
    s.fake.readGate!.complete();
    await syncing;
    expect(_todoOf(s, t.id).time, '16:00');
    expect(s.fake.events['e1']!.time, '16:00');
    s.fake.readGate = Completer<void>();
    final startedDelete = s.fake.readStarted = Completer<void>();
    final deleting = s.repo.sync();
    await startedDelete.future;
    await s.journal.deleteTodo(t.id);
    s.fake.readGate!.complete();
    await deleting;
    expect(s.journal.todos, isEmpty);
    s.fake.readGate = null;
    await s.repo.sync();
    expect(s.fake.events, isEmpty);
  });

  test('시간 지정 신규 투두의 시각을 캘린더로 보낸다', () async {
    final s = await _setup();
    await s.repo.enable(_cal);
    await s.journal.addTodo('회의', _future(1), time: '14:30');
    await s.repo.sync();
    expect(s.fake.events.values.single.time, '14:30');
    expect(s.fake.events.values.single.allDay, false);
  });

  group('앱에서 캘린더로', () {
    test('연동을 켜기 전에는 캘린더를 건드리지 않는다', () async {
      final s = await _setup();
      await _addTodo(s, '병원', '2026-10-20');
      await s.repo.sync();
      expect(s.fake.events, isEmpty);
    });

    test('투두를 종일 일정으로 만들고, 바뀐 것만 고치고, 지운 투두의 일정은 지운다', () async {
      final s = await _setup();
      await s.repo.enable(_cal);
      final t = await _addTodo(s, '병원', '2026-10-20');
      await s.repo.sync();
      expect(s.fake.events.values.single.title, '병원');
      expect(s.fake.events.values.single.day, DateTime(2026, 10, 20));

      s.fake.log.clear();
      await s.repo.sync();
      expect(s.fake.log, isEmpty, reason: '변화가 없으면 아무것도 하지 않는다');

      await s.journal.updateTodo(t.copyWith(date: '2026-10-22', done: true));
      await s.repo.sync();
      expect(s.fake.log, ['update e1']);
      expect(s.fake.events['e1']!.title, '✔ 병원');
      expect(s.fake.events['e1']!.day, DateTime(2026, 10, 22));

      await s.journal.deleteTodo(t.id);
      await s.repo.sync();
      expect(s.fake.events, isEmpty);
      expect(s.repo.linkedCount, 0);
    });

    test('다른 캘린더로 바꾸면 이전 일정을 지우고 새 캘린더에 만든다', () async {
      final s = await _setup();
      await s.repo.enable(_cal);
      await _addTodo(s, '회의', '2026-10-20');
      await s.repo.sync();
      await s.repo.enable(
        const CalendarChoice(
          id: 'c2',
          name: '업무',
          account: '',
          isPrimary: false,
        ),
      );
      await s.repo.sync();
      expect(s.fake.events.length, 1);
      expect(s.fake.log, ['create e1', 'delete e1', 'create e2']);
    });

    test('권한이 없으면 동기화하지 않고, 설정과 연결은 다시 읽어도 유지된다', () async {
      final s = await _setup();
      await s.repo.enable(_cal);
      await s.repo.setImportNew(true);
      s.fake.permission = false;
      await _addTodo(s, '회의', '2026-10-20');
      await s.repo.sync();
      expect(s.fake.events, isEmpty);

      s.fake.permission = true;
      await s.repo.sync();
      final again = CalendarRepository(
        await StorageService.create(),
        s.fake,
        s.journal,
      );
      await again.load();
      expect(again.enabled, isTrue);
      expect(again.importNew, isTrue);
      expect(again.pullChanges, isTrue);
      expect(again.calendarName, '개인');
      expect(again.linkedCount, 1);
    });

    test('연동을 끄면 일정은 남기고, 모두 지우기를 누르면 우리가 만든 일정과 기록을 지운다', () async {
      final s = await _setup();
      await s.repo.enable(_cal);
      await _addTodo(s, '회의', '2026-10-20');
      await s.repo.sync();
      await s.repo.disable();
      await s.repo.sync();
      expect(s.fake.events.length, 1, reason: '꺼진 동안에는 건드리지 않는다');
      await s.repo.removeAllEvents();
      expect(s.fake.events, isEmpty);
      expect(s.repo.linkedCount, 0);
    });
  });

  group('캘린더에서 앱으로', () {
    test('캘린더에서 제목과 날짜를 바꾸면 투두에 반영된다', () async {
      final s = await _setup();
      await s.repo.enable(_cal);
      final t = await _addTodo(s, '병원', '2026-10-20');
      await s.repo.sync();
      s.fake.events['e1']!
        ..title = '치과'
        ..day = DateTime(2026, 10, 25);
      await s.repo.sync();
      expect(_todoOf(s, t.id).text, '치과');
      expect(_todoOf(s, t.id).date, '2026-10-25');

      s.fake.log.clear();
      await s.repo.sync();
      expect(s.fake.log, isEmpty, reason: '반영한 뒤에는 다시 보내지 않는다');
    });

    test('캘린더에서 제목 앞에 체크 표시를 붙이거나 떼면 완료 상태가 바뀐다', () async {
      final s = await _setup();
      await s.repo.enable(_cal);
      final t = await _addTodo(s, '운동', '2026-10-20');
      await s.repo.sync();
      s.fake.events['e1']!.title = '✔ 운동';
      await s.repo.sync();
      expect(_todoOf(s, t.id).done, isTrue);
      expect(_todoOf(s, t.id).text, '운동');
      s.fake.events['e1']!.title = '운동';
      await s.repo.sync();
      expect(_todoOf(s, t.id).done, isFalse);
    });

    test('캘린더에서 일정을 지우면 투두도 지워진다', () async {
      final s = await _setup();
      await s.repo.enable(_cal);
      await _addTodo(s, '회의', '2026-10-20');
      await s.repo.sync();
      s.fake.events.clear();
      await s.repo.sync();
      expect(s.journal.todos, isEmpty);
      expect(s.repo.linkedCount, 0);
    });

    test('반영을 끄면 캘린더의 변화를 무시하고, 지워진 일정은 새로 만든다', () async {
      final s = await _setup();
      await s.repo.enable(_cal);
      await s.repo.setPullChanges(false);
      final t = await _addTodo(s, '회의', '2026-10-20');
      await s.repo.sync();
      s.fake.events['e1']!.title = '다른 제목';
      await s.repo.sync();
      expect(_todoOf(s, t.id).text, '회의');
      s.fake.events.clear();
      await s.repo.sync();
      expect(s.journal.todos.length, 1);
      expect(s.fake.events.length, 1, reason: '지워진 일정은 다시 만든다');
    });

    test('같은 필드를 양쪽에서 바꾸면 투두가 이기고, 다른 필드는 각자 가져온다', () async {
      final s = await _setup();
      await s.repo.enable(_cal);
      final t = await _addTodo(s, '병원', '2026-10-20');
      await s.repo.sync();
      // 앱에서는 제목을, 캘린더에서는 제목과 날짜를 바꿨다
      await s.journal.updateTodo(t.copyWith(text: '앱 제목'));
      s.fake.events['e1']!
        ..title = '캘린더 제목'
        ..day = DateTime(2026, 10, 30);
      await s.repo.sync();
      expect(_todoOf(s, t.id).text, '앱 제목', reason: '제목은 투두가 이긴다');
      expect(s.fake.events['e1']!.title, '앱 제목');
      expect(_todoOf(s, t.id).date, '2026-10-30', reason: '날짜는 캘린더만 바꿨으니 가져온다');
      expect(s.fake.events['e1']!.day, DateTime(2026, 10, 30));
    });
  });

  group('새 일정 가져오기', () {
    test('연동을 켜기만 해도 캘린더의 새 일정이 자동으로 투두가 된다', () async {
      final s = await _setup();
      await s.repo.enable(_cal);
      expect(s.repo.importNew, isTrue);
      s.fake.events['x'] = _Ev('치과', DateTime.parse('${_future(3)}T00:00:00'));
      await s.repo.sync();
      expect(s.journal.todos.single.text, '치과');
    });

    test('예전에 꺼진 채 저장된 설정도 한 번 켜지고, 그 뒤 직접 끄면 유지된다', () async {
      SharedPreferences.setMockInitialValues({
        'calendar': '{"enabled":true,"calendarId":"c1","calendarName":"내 캘린더","importNew":false,"links":{}}',
      });
      final store = await StorageService.create();
      final journal = JournalRepository(store);
      await journal.load();
      final fake = _FakeCalendar();
      var repo = CalendarRepository(store, fake, journal);
      await repo.load();
      expect(repo.importNew, isTrue, reason: '예전 기본값(꺼짐)에서 올라오면 한 번 켠다');
      await repo.setImportNew(false);
      repo = CalendarRepository(store, fake, journal);
      await repo.load();
      expect(repo.importNew, isFalse, reason: '사용자가 직접 끈 것은 존중한다');
    });

    test('시각이 있는 일정은 시간까지 투두로 가져오고, 캘린더에서 시간을 바꾸면 따라간다', () async {
      final s = await _setup();
      await s.repo.enable(_cal);
      final day = DateTime.parse('${_future(3)}T00:00:00');
      s.fake.events['x'] = _Ev('회의', day, time: '14:30')..allDay = false;
      s.fake.events['y'] = _Ev('종일 일정', day);
      await s.repo.sync();
      expect(s.journal.todos.firstWhere((t) => t.text == '회의').time, '14:30');
      expect(s.journal.todos.firstWhere((t) => t.text == '종일 일정').time, '');
      s.fake.events['x']!.time = '16:00';
      await s.repo.sync();
      expect(s.journal.todos.firstWhere((t) => t.text == '회의').time, '16:00');
    });

    test('캘린더 시간을 가져오는 사이 앱에서 바꾼 완료 상태를 되돌리지 않는다', () async {
      final s = await _setup();
      await s.repo.enable(_cal);
      final day = DateTime.parse('${_future(3)}T00:00:00');
      s.fake.events['x'] = _Ev('회의', day, time: '14:30')..allDay = false;
      await s.repo.sync();
      final t = s.journal.todos.single;
      s.fake.events['x']!.time = '16:00';
      await s.journal.updateTodo(t.copyWith(done: true)); // 앱에서 완료 처리
      await s.repo.sync();
      final cur = s.journal.todos.single;
      expect(cur.time, '16:00');
      expect(cur.done, isTrue, reason: '시간을 가져오며 완료 상태를 미완료로 되돌리면 안 된다');
    });

    test(
      '연동한 캘린더가 아닌 다른 쓰기 가능 캘린더의 일정도 기본으로 가져오고, 공휴일 같은 읽기 전용과 숨긴 캘린더는 가져오지 않는다',
      () async {
        final s = await _setup();
        await s.repo.enable(_cal);
        final day = DateTime.parse('${_future(3)}T00:00:00');
        s.fake.events['a'] = _Ev('개인 일정', day);
        s.fake.events['b'] = _Ev('업무 일정', day, calendarId: 'c2');
        s.fake.events['c'] = _Ev('추석 연휴', day, calendarId: 'c3');
        s.fake.events['d'] = _Ev('숨긴 캘린더 일정', day, calendarId: 'c4');
        await s.repo.sync();
        expect(s.journal.todos.map((t) => t.text).toSet(), {'개인 일정', '업무 일정'});
        await s.repo.sync();
        await s.repo.sync();
        expect(
          s.journal.todos.length,
          2,
          reason: '다른 캘린더에서 가져온 일정이 매번 다시 만들어지거나 연결이 끊기면 안 된다',
        );
      },
    );

    test(
      '가져올 캘린더를 직접 고르면 그 캘린더만 가져오고, 설정은 다시 읽어도 유지되며, 기본값으로 되돌릴 수 있다',
      () async {
        final s = await _setup();
        await s.repo.enable(_cal);
        final day = DateTime.parse('${_future(3)}T00:00:00');
        s.fake.events['a'] = _Ev('개인 일정', day);
        s.fake.events['b'] = _Ev('업무 일정', day, calendarId: 'c2');
        s.fake.events['c'] = _Ev('추석 연휴', day, calendarId: 'c3');
        await s.repo.setImportCalendars({'c3'});
        await s.repo.sync();
        expect(s.journal.todos.map((t) => t.text).toSet(), {
          '개인 일정',
          '추석 연휴',
        }, reason: '고른 캘린더와 연동 캘린더(항상 포함)');
        expect(s.repo.importCalendarIds, {'c3'});
        final choices = await s.repo.importChoices();
        expect(choices.map((c) => c.id), [
          'c1',
          'c2',
          'c3',
        ], reason: '숨긴 캘린더는 목록에서 뺀다');
        expect(choices.firstWhere((c) => c.id == 'c3').readOnly, isTrue);

        final store = await StorageService.create();
        final again = CalendarRepository(store, s.fake, s.journal);
        await again.load();
        expect(again.importCalendarIds, {'c3'}, reason: '설정이 유지된다');
        await again.setImportCalendars(null);
        expect(again.importCalendarIds, isNull);
      },
    );

    test('꺼져 있으면 가져오지 않는다', () async {
      final s = await _setup();
      await s.repo.enable(_cal);
      await s.repo.setImportNew(false);
      s.fake.events['x'] = _Ev('치과', DateTime.parse('${_future(3)}T00:00:00'));
      await s.repo.sync();
      expect(s.journal.todos, isEmpty);
    });

    test('범위 안의 반복되지 않는 일정만 투두로 만들고 두 번 만들지 않는다', () async {
      final s = await _setup();
      await s.repo.enable(_cal);
      await s.repo.setImportNew(true);
      s.fake.events['x'] = _Ev('치과', DateTime.parse('${_future(3)}T00:00:00'));
      s.fake.events['far'] = _Ev(
        '먼 일정',
        DateTime.parse('${_future(200)}T00:00:00'),
      );
      s.fake.events['rec'] = _Ev(
        '주간 회의',
        DateTime.parse('${_future(2)}T00:00:00'),
        recurring: true,
      );
      s.fake.events['blank'] = _Ev(
        '  ',
        DateTime.parse('${_future(2)}T00:00:00'),
      );
      s.fake.events['done'] = _Ev(
        '✔ 끝낸 일',
        DateTime.parse('${_future(1)}T00:00:00'),
      );
      await s.repo.sync();
      expect(s.journal.todos.map((t) => t.text).toSet(), {'치과', '끝낸 일'});
      expect(s.journal.todos.firstWhere((t) => t.text == '끝낸 일').done, isTrue);
      expect(
        s.journal.todos.firstWhere((t) => t.text == '치과').date,
        _future(3),
      );

      await s.repo.sync();
      expect(s.journal.todos.length, 2, reason: '한 번 가져온 일정은 다시 만들지 않는다');
      expect(s.fake.events.length, 5, reason: '가져온 일정은 캘린더에서 지우지 않는다');
    });

    test('가져온 투두를 지워도 캘린더 일정은 남고 다시 가져오지 않는다', () async {
      final s = await _setup();
      await s.repo.enable(_cal);
      await s.repo.setImportNew(true);
      s.fake.events['x'] = _Ev('치과', DateTime.parse('${_future(3)}T00:00:00'));
      await s.repo.sync();
      await s.journal.deleteTodo(s.journal.todos.single.id);
      await s.repo.sync();
      expect(s.fake.events.containsKey('x'), isTrue);
      expect(s.journal.todos, isEmpty);
      await s.repo.sync();
      expect(s.journal.todos, isEmpty, reason: '다시 가져오지 않는다');
    });

    test('가져온 쓰기 가능 일정의 날짜와 완료를 수정한다', () async {
      final s = await _setup();
      await s.repo.enable(_cal);
      await s.repo.setImportNew(true);
      final day = DateTime.parse('${_future(3)}T00:00:00');
      s.fake.events['x'] = _Ev('치과', day);
      await s.repo.sync();
      final t = s.journal.todos.single;
      await s.journal.updateTodo(t.copyWith(done: true, date: _future(9)));
      await s.repo.sync();
      expect(s.fake.events['x']!.title, '✔ 치과');
      expect(s.fake.events['x']!.day, DateTime.parse('${_future(9)}T00:00:00'));

      s.fake.log.clear();
      await s.repo.sync();
      expect(s.fake.log, isEmpty, reason: '날짜가 어긋나 있어도 반복해서 보내지 않는다');
    });
  });
}
