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
  _Ev(this.title, this.day, {this.recurring = false, this.time = ''});
  String title;
  DateTime day;
  bool allDay = true;
  bool recurring;
  String time;
}

/// 기기 캘린더 대신 이벤트를 메모리에 들고 있는 가짜 서비스.
class _FakeCalendar implements CalendarService {
  bool permission = true;
  int nextId = 1;
  final Map<String, _Ev> events = {};
  final List<String> log = [];

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<List<Calendar>> writableCalendars() async => [];

  @override
  Future<CalendarEvent?> get(String eventId) async {
    final e = events[eventId];
    return e == null ? null : CalendarEvent(id: eventId, title: e.title, day: e.day, allDay: e.allDay, recurring: e.recurring, time: e.time);
  }

  @override
  Future<List<CalendarEvent>> listBetween({required String calendarId, required DateTime from, required DateTime to}) async => [
        for (final entry in events.entries)
          if (!entry.value.day.isBefore(from) && entry.value.day.isBefore(to))
            CalendarEvent(
              id: entry.key,
              title: entry.value.title,
              day: entry.value.day,
              allDay: entry.value.allDay,
              recurring: entry.value.recurring,
              time: entry.value.time,
            )
      ];

  @override
  Future<String> create({required String calendarId, required String title, required DateTime day}) async {
    final id = 'e${nextId++}';
    events[id] = _Ev(title, day);
    log.add('create $id');
    return id;
  }

  @override
  Future<bool> update({required String eventId, String? title, DateTime? day}) async {
    final e = events[eventId];
    if (e == null) return false;
    if (title != null) e.title = title;
    if (day != null) {
      e.day = day;
      e.allDay = true;
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

const _cal = CalendarChoice(id: 'c1', name: '개인', account: 'me@example.com', isPrimary: true);

typedef _Setup = ({CalendarRepository repo, JournalRepository journal, _FakeCalendar fake});

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

Future<Todo> _addTodo(_Setup s, String text, String date) => s.journal.addTodo(text, date);

Todo _todoOf(_Setup s, String id) => s.journal.todos.firstWhere((t) => t.id == id);

String _future(int days) => addDaysKey(todayKey(), days);

void main() {
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
      await s.repo.enable(const CalendarChoice(id: 'c2', name: '업무', account: '', isPrimary: false));
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
      final again = CalendarRepository(await StorageService.create(), s.fake, s.journal);
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
      s.fake.events['far'] = _Ev('먼 일정', DateTime.parse('${_future(200)}T00:00:00'));
      s.fake.events['rec'] = _Ev('주간 회의', DateTime.parse('${_future(2)}T00:00:00'), recurring: true);
      s.fake.events['blank'] = _Ev('  ', DateTime.parse('${_future(2)}T00:00:00'));
      s.fake.events['done'] = _Ev('✔ 끝낸 일', DateTime.parse('${_future(1)}T00:00:00'));
      await s.repo.sync();
      expect(s.journal.todos.map((t) => t.text).toSet(), {'치과', '끝낸 일'});
      expect(s.journal.todos.firstWhere((t) => t.text == '끝낸 일').done, isTrue);
      expect(s.journal.todos.firstWhere((t) => t.text == '치과').date, _future(3));

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

    test('가져온 투두의 완료 표시는 캘린더 제목에 붙이고, 날짜는 옮기지 않는다', () async {
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
      expect(s.fake.events['x']!.day, day, reason: '가져온 일정은 날짜를 옮기지 않는다');

      s.fake.log.clear();
      await s.repo.sync();
      expect(s.fake.log, isEmpty, reason: '날짜가 어긋나 있어도 반복해서 보내지 않는다');
    });
  });
}
