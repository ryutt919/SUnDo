import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_routine/data/repositories/routine_repository.dart';
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

void main() {
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

  test('모드는 10개까지만 만들 수 있고, 모드를 지우면 습관의 모드 지정도 정리된다', () async {
    final repo = await emptyRoutine();
    for (var i = 0; i < 20; i++) {
      await repo.addMode('모드$i');
    }
    expect(repo.modes.length, RoutineRepository.maxModes);
    final extra = repo.modes.last.id;
    await repo.addHabit(habit('a', modes: [extra]));
    await repo.deleteMode(extra);
    expect(repo.habitById('a')!.modes, isEmpty);
  });

  test('보이는 습관만 재정렬해도 숨은 습관의 자리는 그대로다', () async {
    final repo = await emptyRoutine();
    for (final id in ['a', 'b', 'c', 'd']) {
      await repo.addHabit(habit(id));
    }
    await repo.reorderVisible(['c', 'a', 'd']); // b는 화면에 없음
    expect(repo.habits.map((h) => h.id), ['c', 'b', 'a', 'd']);
  });

  test('기간 쉬기는 시작일부터 종료일까지 모두 표시한다', () async {
    final repo = await emptyRoutine();
    await repo.setRestRange('2026-10-10', '2026-10-13', true);
    expect(repo.restDates.toSet(), {'2026-10-10', '2026-10-11', '2026-10-12', '2026-10-13'});
  });
}
