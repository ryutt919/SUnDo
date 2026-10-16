import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_routine/ui/core/habit_timer_manager.dart';
import 'package:my_routine/data/repositories/backup_repository.dart';
import 'package:my_routine/data/repositories/journal_repository.dart';
import 'package:my_routine/data/repositories/routine_repository.dart';
import 'package:my_routine/data/repositories/settings_repository.dart';
import 'package:my_routine/data/services/backup_service.dart';
import 'package:my_routine/data/services/photo_service.dart';
import 'package:my_routine/data/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

/// 웹앱에서 내보낸 백업과 같은 형식의 샘플.
const _webBackup = {
  'habits': [
    {
      'id': 'h1', 'emoji': '💧', 'name': '물 마시기', 'time': '07:00', 'context': '', 'color': '#DDF1FF',
      'repeat': {'type': 'weekdays', 'days': [1, 2, 3], 'times': 3, 'every': 2, 'monthDays': [1]},
      'levels': {'mini': '', 'plus': '컵 하나', 'max': ''}, 'alts': ['차'], 'alarm': '07:00', 'unit': '', 'timerMin': 0,
      'modes': [], 'archived': false, 'start': '2026-10-01',
    },
  ],
  'modes': [{'id': 'm1', 'name': '기본'}],
  'activeMode': 'm1',
  'logs': {
    '2026-10-13': {'h1': {'done': true, 'level': 'plus', 'alt': '차', 'value': 2}},
  },
  'rest': {'2026-10-12': true},
};

/// 파일 선택 없이 정해진 JSON을 돌려주는 가짜 백업 서비스.
class _FakeBackupService extends BackupService {
  _FakeBackupService(this._data);
  final Map<String, dynamic> _data;

  @override
  Future<Map<String, dynamic>?> pick() async => _data;
}

/// 파일 시스템 없이 메모리에서 사진 파일을 흉내 내는 가짜 사진 서비스.
class _FakePhotoService extends PhotoService {
  final Map<String, List<int>> files = {};

  @override
  Future<String?> readBase64(String path) async {
    final b = files[path];
    return b == null ? null : base64Encode(b);
  }

  @override
  Future<String> restore(String name, List<int> bytes) async {
    final path = '/restored/$name';
    files[path] = bytes;
    return path;
  }
}

void main() {
  test('인증 사진은 백업에 담겼다가 불러올 때 파일로 복원된다', () async {
    final routine = await emptyRoutine();
    final store = await StorageService.create();
    final journal = JournalRepository(store);
    await journal.load();
    final settings = SettingsRepository(store);
    await settings.load();
    final photos = _FakePhotoService()..files['/data/proofs/111.jpg'] = [1, 2, 3, 4];

    await routine.addHabit(habit('a'));
    await routine.updateLog('a', '2026-10-13', (l) => l.copyWith(done: true, photo: '/data/proofs/111.jpg'));
    await routine.updateLog('a', '2026-10-12', (l) => l.copyWith(done: true, photo: '/data/proofs/missing.jpg'));

    // 내보내기: 사진은 photoFiles에 담기고, 사라진 파일의 연결은 빠진다
    final exporter = BackupRepository(_FakeBackupService({}), photos, routine, journal, settings);
    final exported = await exporter.buildExport();
    expect((exported['photoFiles'] as Map).keys, ['111.jpg']);
    final logs = exported['logs'] as Map;
    expect(((logs['2026-10-13'] as Map)['a'] as Map)['photo'], 'photos/111.jpg');
    expect(((logs['2026-10-12'] as Map)['a'] as Map).containsKey('photo'), isFalse);

    // 불러오기: 다른 기기처럼 빈 저장소에 복원
    final other = await emptyRoutine();
    final restoredPhotos = _FakePhotoService();
    final importer = BackupRepository(
      _FakeBackupService(jsonDecode(jsonEncode(exported)) as Map<String, dynamic>),
      restoredPhotos,
      other,
      journal,
      settings,
    );
    expect(await importer.importFromFile(), isTrue);
    final path = other.logOf('a', '2026-10-13')!.photo!;
    expect(path, '/restored/111.jpg');
    expect(restoredPhotos.files[path], [1, 2, 3, 4]);
  });

  test('체크는 저장소를 거쳐 디스크에 남고 다시 읽으면 복원된다', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await StorageService.create();
    final repo = RoutineRepository(store);
    await repo.load();
    expect(repo.habits, isNotEmpty, reason: '처음 실행하면 예시 습관이 생긴다');

    final id = repo.habits.first.id;
    await repo.toggle(id, '2026-10-13');
    expect(repo.isDone(id, '2026-10-13'), isTrue);

    final again = RoutineRepository(store);
    await again.load();
    expect(again.isDone(id, '2026-10-13'), isTrue);
  });

  test('웹앱 백업 JSON을 불러올 수 있다', () async {
    final repo = await emptyRoutine();
    await repo.importJson(jsonDecode(jsonEncode(_webBackup)) as Map<String, dynamic>);
    final h = repo.habitById('h1')!;
    expect(h.name, '물 마시기');
    expect(h.repeat.days, [1, 2, 3]);
    expect(h.alts, ['차']);
    expect(repo.logOf('h1', '2026-10-13')!.alt, '차');
    expect(repo.logOf('h1', '2026-10-13')!.value, 2.0);
    expect(repo.isRest('2026-10-12'), isTrue);
  });

  test('내보낸 데이터를 다시 불러오면 같다', () async {
    final repo = await emptyRoutine();
    await repo.importJson(jsonDecode(jsonEncode(_webBackup)) as Map<String, dynamic>);
    final exported = jsonDecode(jsonEncode(repo.exportJson())) as Map<String, dynamic>;
    final other = await emptyRoutine();
    await other.importJson(exported);
    expect(jsonEncode(other.exportJson()), jsonEncode(repo.exportJson()));
  });

  test('모드는 10개까지만 만들 수 있다', () async {
    final repo = await emptyRoutine();
    for (var i = 0; i < 20; i++) {
      await repo.addMode('모드$i');
    }
    expect(repo.modes.length, RoutineRepository.maxModes);
  });

  test('삭제한 습관의 기록은 새로 만들어지지 않는다', () async {
    final repo = await emptyRoutine();
    await repo.addHabit(habit('a'));
    await repo.deleteHabit('a');
    await repo.setDone('a', '2026-10-13', true);
    expect(repo.isDone('a', '2026-10-13'), isFalse);
    expect(repo.totalChecks, 0);
  });

  test('습관 삭제 중 타이머가 끝나도 유령 기록이 생기지 않는다', () async {
    final repo = await emptyRoutine();
    await repo.addHabit(habit('a'));
    final timers = HabitTimerManager(repo);
    fakeAsync((async) {
      timers.start('a', '2026-10-14', 1);
      async.elapse(const Duration(seconds: 10));
      repo.deleteHabit('a');
      async.flushMicrotasks();
      expect(timers.secondsLeft('a', '2026-10-14'), isNull, reason: '삭제하면 타이머도 멈춘다');
      async.elapse(const Duration(seconds: 70));
      async.flushMicrotasks();
    });
    await Future<void>.delayed(Duration.zero);
    expect(repo.totalChecks, 0);
  });

  test('앱 사진 폴더 밖을 가리키는 백업 사진 경로는 연결을 끊고 설정 타입이 틀린 백업은 거부한다', () async {
    final routine = await emptyRoutine();
    final store = await StorageService.create();
    final journal = JournalRepository(store);
    await journal.load();
    final settings = SettingsRepository(store);
    await settings.load();

    // 설정 최상위 타입이 틀린 백업은 아무것도 바꾸지 않고 거부
    await routine.addHabit(habit('keep'));
    final bad = BackupRepository(
      _FakeBackupService({'habits': <dynamic>[], 'logs': <String, dynamic>{}, 'settings': 'broken'}),
      _FakePhotoService(),
      routine,
      journal,
      settings,
    );
    await expectLater(bad.importFromFile(), throwsFormatException);
    expect(routine.habits.map((h) => h.id), ['keep']);

    // 임의 경로(photos/ 표시가 아님)를 가진 사진 연결은 가져오지 않는다
    final evil = BackupRepository(
      _FakeBackupService({
        'habits': [
          {'id': 'h', 'name': 'x', 'start': '2026-10-01'}
        ],
        'logs': {
          '2026-10-13': {
            'h': {'done': true, 'photo': '/data/data/other_app/secret.db'}
          }
        },
      }),
      _FakePhotoService(),
      routine,
      journal,
      settings,
    );
    expect(await evil.importFromFile(), isTrue);
    expect(routine.logOf('h', '2026-10-13')!.photo, isNull);
    expect(routine.isDone('h', '2026-10-13'), isTrue, reason: '체크 자체는 가져온다');
  });

  test('보이는 습관만 재정렬해도 숨은 습관의 자리는 그대로다', () async {
    final repo = await emptyRoutine();
    for (final id in ['a', 'b', 'c', 'd']) {
      await repo.addHabit(habit(id));
    }
    await repo.reorderVisible(['c', 'a', 'd']); // b는 화면에 없음
    expect(repo.habits.map((h) => h.id), ['c', 'b', 'a', 'd']);
  });

  test('형식이 틀린 백업을 불러오면 기존 데이터는 그대로 남는다', () async {
    final repo = await emptyRoutine();
    await repo.addHabit(habit('keep', name: '지키기'));
    await repo.setDone('keep', '2026-10-13', true);
    // id가 없는 습관이 섞인 잘못된 백업
    expect(
      () => repo.importJson({
        'habits': [{'name': 'id 없음', 'start': '2026-10-01'}],
        'logs': <String, dynamic>{},
      }),
      throwsFormatException,
    );
    expect(repo.habits.map((h) => h.id), ['keep']);
    expect(repo.isDone('keep', '2026-10-13'), isTrue);
    final again = RoutineRepository(await StorageService.create());
    await again.load();
    expect(again.habits.map((h) => h.id), ['keep'], reason: '디스크도 그대로');
  });

  test('설정 부분이 틀린 전체 백업도 아무것도 바꾸지 않는다', () async {
    final routine = await emptyRoutine();
    final store = await StorageService.create();
    final journal = JournalRepository(store);
    await journal.load();
    final settings = SettingsRepository(store);
    await settings.load();
    await routine.addHabit(habit('keep'));
    final backup = BackupRepository(_FakeBackupService({
      'habits': <dynamic>[],
      'logs': <String, dynamic>{},
      'settings': {'doneToBottom': 'bad'}, // bool이어야 하는 값이 문자열
    }), _FakePhotoService(), routine, journal, settings);
    await expectLater(backup.importFromFile(), throwsFormatException);
    expect(routine.habits.map((h) => h.id), ['keep'], reason: '습관 데이터는 그대로');
  });

  test('습관이나 모드를 삭제해도 위젯이 방금 한 체크는 남는다', () async {
    final app = await emptyRoutine();
    await app.addHabit(habit('a'));
    await app.addHabit(habit('b'));
    await app.addMode('두번째');
    final widget = RoutineRepository(await StorageService.create());
    await widget.load();
    await widget.toggle('b', '2026-10-13'); // 위젯이 체크 (앱은 아직 모름)
    await app.deleteMode(app.modes.last.id);
    await app.deleteHabit('a');
    final check = RoutineRepository(await StorageService.create());
    await check.load();
    expect(check.isDone('b', '2026-10-13'), isTrue);
  });

  test('앱과 위젯(다른 인스턴스)이 번갈아 체크해도 서로의 기록을 덮어쓰지 않는다', () async {
    final app = await emptyRoutine();
    await app.addHabit(habit('a'));
    await app.addHabit(habit('b'));
    final widget = RoutineRepository(await StorageService.create());
    await widget.load();
    await widget.toggle('b', '2026-10-13'); // 위젯이 체크
    await app.toggle('a', '2026-10-13'); // 앱은 위젯의 변경을 아직 모르는 상태에서 체크
    final check = RoutineRepository(await StorageService.create());
    await check.load();
    expect(check.isDone('a', '2026-10-13'), isTrue);
    expect(check.isDone('b', '2026-10-13'), isTrue, reason: '위젯의 체크가 유실되면 안 된다');
  });

  test('기간 쉬기는 시작일부터 종료일까지 모두 표시한다', () async {
    final repo = await emptyRoutine();
    await repo.setRestRange('2026-10-10', '2026-10-13', true);
    expect(repo.restDates.toSet(), {'2026-10-10', '2026-10-11', '2026-10-12', '2026-10-13'});
  });
}
