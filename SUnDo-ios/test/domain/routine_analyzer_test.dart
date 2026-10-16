import 'package:flutter_test/flutter_test.dart';
import 'package:my_routine/data/repositories/routine_repository.dart';
import 'package:my_routine/data/services/storage_service.dart';
import 'package:my_routine/domain/models/repeat_rule.dart';
import 'package:my_routine/domain/use_cases/routine_analyzer.dart';
import 'package:my_routine/domain/use_cases/stats_use_case.dart';
import 'package:my_routine/ui/features/habit_form/view_models/habit_form_view_model.dart';

import '../test_helpers.dart';

void main() {
  // 2026-10-14 수요일을 오늘로 고정한다.
  const today = '2026-10-14';

  group('반복 규칙', () {
    test('매일은 시작일 이후 항상 해야 한다', () async {
      final repo = await emptyRoutine();
      await repo.addHabit(habit('a', start: '2026-10-01'));
      final an = RoutineAnalyzer(repo, today: () => today);
      final h = repo.habitById('a')!;
      expect(an.isDue(h, '2026-09-30'), isFalse, reason: '시작일 전');
      expect(an.isDue(h, '2026-10-01'), isTrue);
      expect(an.isDue(h, '2026-10-20'), isTrue);
    });

    test('요일 지정은 선택한 요일에만 해야 한다 (일요일=0)', () async {
      final repo = await emptyRoutine();
      await repo.addHabit(habit('a', repeat: const RepeatRule(type: RepeatType.weekdays, days: [1, 3])));
      final an = RoutineAnalyzer(repo, today: () => today);
      final h = repo.habitById('a')!;
      expect(an.isDue(h, '2026-10-12'), isTrue, reason: '월요일');
      expect(an.isDue(h, '2026-10-13'), isFalse, reason: '화요일');
      expect(an.isDue(h, '2026-10-14'), isTrue, reason: '수요일');
    });

    test('N일마다는 시작일 기준으로 간격을 센다', () async {
      final repo = await emptyRoutine();
      await repo.addHabit(habit('a', start: '2026-10-01', repeat: const RepeatRule(type: RepeatType.interval, every: 3)));
      final an = RoutineAnalyzer(repo, today: () => today);
      final h = repo.habitById('a')!;
      expect(an.isDue(h, '2026-10-01'), isTrue);
      expect(an.isDue(h, '2026-10-02'), isFalse);
      expect(an.isDue(h, '2026-10-04'), isTrue);
      expect(an.isDue(h, '2026-10-07'), isTrue);
    });

    test('매월 특정 날짜', () async {
      final repo = await emptyRoutine();
      await repo.addHabit(habit('a', repeat: const RepeatRule(type: RepeatType.monthDays, monthDays: [1, 15])));
      final an = RoutineAnalyzer(repo, today: () => today);
      final h = repo.habitById('a')!;
      expect(an.isDue(h, '2026-10-15'), isTrue);
      expect(an.isDue(h, '2026-10-16'), isFalse);
      expect(an.isDue(h, '2026-11-01'), isTrue);
    });

    test('주 N회는 목표를 채우면 이후 날에는 나타나지 않고, 지난 미체크는 실패로 세지 않는다', () async {
      final repo = await emptyRoutine();
      await repo.addHabit(habit('a', repeat: const RepeatRule(type: RepeatType.weekly, times: 2)));
      final an = RoutineAnalyzer(repo, today: () => today);
      final h = repo.habitById('a')!;
      expect(an.isDue(h, '2026-10-13'), isFalse, reason: '지난 날 미체크');
      expect(an.isDue(h, '2026-10-14'), isTrue);
      await repo.setDone('a', '2026-10-12', true);
      await repo.setDone('a', '2026-10-13', true);
      expect(an.isDue(h, '2026-10-14'), isFalse, reason: '이번 주 2회 달성');
      expect(an.isDue(h, '2026-10-12'), isTrue, reason: '체크한 날은 계속 표시');
    });

    test('종료일 이후에는 나타나지 않는다', () async {
      final repo = await emptyRoutine();
      await repo.addHabit(habit('a').copyWith(finishedOn: '2026-10-10'));
      final an = RoutineAnalyzer(repo, today: () => today);
      final h = repo.habitById('a')!;
      expect(an.isDue(h, '2026-10-10'), isTrue);
      expect(an.isDue(h, '2026-10-11'), isFalse);
    });
  });

  group('신호등', () {
    test('60% 이상 초록, 20% 이상 노랑, 그 미만 빨강', () async {
      final repo = await emptyRoutine();
      for (final id in ['a', 'b', 'c', 'd', 'e']) {
        await repo.addHabit(habit(id));
      }
      final an = RoutineAnalyzer(repo, today: () => today);
      const d = '2026-10-13';
      expect(an.lightOf(an.dayStat(d), d), TrafficLight.red, reason: '0/5');
      await repo.setDone('a', d, true);
      expect(an.lightOf(an.dayStat(d), d), TrafficLight.yellow, reason: '1/5 = 20%');
      await repo.setDone('b', d, true);
      await repo.setDone('c', d, true);
      expect(an.lightOf(an.dayStat(d), d), TrafficLight.green, reason: '3/5 = 60%');
    });

    test('오늘 0%는 진행 중이라 색을 칠하지 않고, 미래도 칠하지 않는다', () async {
      final repo = await emptyRoutine();
      await repo.addHabit(habit('a'));
      final an = RoutineAnalyzer(repo, today: () => today);
      expect(an.lightOf(an.dayStat(today), today), TrafficLight.none);
      expect(an.lightOf(an.dayStat('2026-10-20'), '2026-10-20'), TrafficLight.none);
    });

    test('쉬는 날은 실패로 세지 않는다', () async {
      final repo = await emptyRoutine();
      await repo.addHabit(habit('a'));
      await repo.setRest('2026-10-13', true);
      final an = RoutineAnalyzer(repo, today: () => today);
      expect(an.dayStat('2026-10-13').rate, isNull);
      expect(an.lightOf(an.dayStat('2026-10-13'), '2026-10-13'), TrafficLight.rest);
    });
  });

  group('연속 일수', () {
    test('초록불이 이어진 날을 세고, 쉬는 날은 건너뛴다', () async {
      final repo = await emptyRoutine();
      await repo.addHabit(habit('a', start: '2026-10-01'));
      final an = RoutineAnalyzer(repo, today: () => today);
      await repo.setDone('a', '2026-10-14', true);
      await repo.setDone('a', '2026-10-13', true);
      await repo.setRest('2026-10-12', true);
      await repo.setDone('a', '2026-10-11', true);
      expect(an.streak(), 3);
      expect(an.habitStreak(repo.habitById('a')!), 3);
    });

    test('오늘 아직 못 했어도 어제까지의 연속은 유지된다', () async {
      final repo = await emptyRoutine();
      await repo.addHabit(habit('a', start: '2026-10-01'));
      final an = RoutineAnalyzer(repo, today: () => today);
      await repo.setDone('a', '2026-10-13', true);
      await repo.setDone('a', '2026-10-12', true);
      expect(an.streak(), 2);
    });
  });

  group('보관', () {
    test('보관해도 과거 달성률과 신호등은 그대로이고 보관한 날부터 사라진다', () async {
      final repo = await emptyRoutine();
      await repo.addHabit(habit('a', start: '2026-10-01'));
      await repo.setDone('a', '2026-10-13', true);
      final an = RoutineAnalyzer(repo, today: () => today);
      expect(an.lightOf(an.dayStat('2026-10-13'), '2026-10-13'), TrafficLight.green);

      // 오늘(10-14) 보관: 어제까지만 나타난다
      await repo.updateHabit(repo.habitById('a')!.copyWith(archived: true, finishedOn: '2026-10-13'));
      expect(an.dayStat('2026-10-13').due, 1, reason: '과거 기록은 유지');
      expect(an.lightOf(an.dayStat('2026-10-13'), '2026-10-13'), TrafficLight.green);
      expect(an.dayStat(today).due, 0, reason: '오늘부터는 사라짐');
    });

    test('이미 종료한 루틴을 보관해도 종료일은 그대로 유지된다', () async {
      final repo = await emptyRoutine();
      await repo.addHabit(habit('a', start: '2026-10-01').copyWith(finishedOn: '2026-10-05'));
      final vm = HabitFormViewModel(repo, habitId: 'a');
      await vm.archive();
      expect(repo.habitById('a')!.finishedOn, '2026-10-05');
      expect(repo.habitById('a')!.archived, isTrue);
    });

    test('보관한 루틴은 보관 전 기간의 루틴별 통계에 남는다', () async {
      final repo = await emptyRoutine();
      await repo.addHabit(habit('a', start: '2026-10-01'));
      await repo.setDone('a', '2026-10-13', true);
      await repo.updateHabit(repo.habitById('a')!.copyWith(archived: true, finishedOn: '2026-10-13'));
      final an = RoutineAnalyzer(repo, today: () => today);
      final stats = StatsUseCase(repo, an).summarize(StatsRange.rolling7);
      expect(stats.habitStats.map((s) => s.habit.id), ['a']);
      expect(stats.habitStats.single.done, 1);
    });

    test('종료일이 없는 보관 루틴(웹 백업)은 어느 날에도 나타나지 않는다', () async {
      final repo = await emptyRoutine();
      await repo.addHabit(habit('a', start: '2026-10-01').copyWith(archived: true));
      final an = RoutineAnalyzer(repo, today: () => today);
      expect(an.dayStat('2026-10-13').due, 0);
    });
  });

  group('모드 이력과 주 목표', () {
    test('모드를 바꿔도 지난 날의 루틴 목록과 달성률은 그날 쓰던 모드 기준으로 남는다', () async {
      final repo = await emptyRoutine();
      await repo.addMode('주말');
      final weekend = repo.modes.last.id;
      await repo.addHabit(habit('onlyWeekend', modes: [weekend]));
      await repo.addHabit(habit('always'));
      final an = RoutineAnalyzer(repo, today: () => today);

      await repo.setActiveMode(weekend, from: today); // 오늘(10-14)부터 주말 모드
      expect(an.dueHabits('2026-10-13').map((h) => h.id), ['always'], reason: '어제는 기본 모드였다');
      expect(an.dueHabits(today).map((h) => h.id), ['onlyWeekend', 'always']);

      // 다시 기본 모드로 돌려도 어제 기록은 변하지 않는다
      await repo.setActiveMode(repo.modes.first.id, from: '2026-10-15');
      expect(an.dueHabits('2026-10-13').map((h) => h.id), ['always']);
      expect(repo.modeOn('2026-10-14'), weekend);
    });

    test('모드 이력은 백업으로 내보내고 불러와도 유지된다', () async {
      final repo = await emptyRoutine();
      await repo.addMode('주말');
      await repo.setActiveMode(repo.modes.last.id, from: '2026-10-10');
      final other = await emptyRoutine();
      await other.importJson(repo.exportJson());
      expect(other.modeOn('2026-10-09'), repo.modes.first.id);
      expect(other.modeOn('2026-10-10'), repo.modes.last.id);
    });

    test('모드를 삭제해도 지난 날의 구성은 그대로이고, 소속 모드가 사라진 루틴은 지금부터 모든 모드에 나타난다', () async {
      final repo = await emptyRoutine();
      await repo.addMode('주말');
      final weekend = repo.modes.last.id;
      await repo.addHabit(habit('onlyWeekend', modes: [weekend]));
      await repo.addHabit(habit('always'));
      final an = RoutineAnalyzer(repo, today: () => today);
      await repo.setActiveMode(weekend, from: '2026-10-10');
      await repo.setActiveMode(repo.modes.first.id, from: '2026-10-12');

      expect(an.dueHabits('2026-10-11').map((h) => h.id), ['onlyWeekend', 'always']);
      expect(an.dueHabits('2026-10-13').map((h) => h.id), ['always']);

      await repo.deleteMode(weekend, on: today);

      expect(an.dueHabits('2026-10-11').map((h) => h.id), ['onlyWeekend', 'always'], reason: '지난 날은 그대로');
      expect(an.dueHabits('2026-10-13').map((h) => h.id), ['always'], reason: '지난 날은 그대로');
      expect(an.dueHabits(today).map((h) => h.id), ['onlyWeekend', 'always'], reason: '삭제한 날부터는 모든 모드에 나타남');

      // 다음 날이 되어 오늘이 과거가 되어도 같은 결과여야 한다(삭제 시점이 이력으로 남아 있다)
      final nextDay = RoutineAnalyzer(repo, today: () => '2026-10-16');
      expect(nextDay.dueHabits('2026-10-14').map((h) => h.id), ['onlyWeekend', 'always']);
      expect(nextDay.dueHabits('2026-10-13').map((h) => h.id), ['always']);
    });

    test('삭제한 모드 이력은 백업으로 내보내고 불러와도 유지된다', () async {
      final repo = await emptyRoutine();
      await repo.addMode('주말');
      final weekend = repo.modes.last.id;
      await repo.deleteMode(weekend, on: '2026-10-12');
      final other = await emptyRoutine();
      await other.importJson(repo.exportJson());
      expect(other.modeDeletedOn(weekend), '2026-10-12');
    });

    test('토글은 위젯이 먼저 바꾼 최신 상태를 기준으로 뒤집는다', () async {
      final app = await emptyRoutine();
      await app.addHabit(habit('a'));
      final widget = RoutineRepository(await StorageService.create());
      await widget.load();
      await widget.toggle('a', '2026-10-13'); // 위젯이 체크 (앱은 아직 모름)
      await app.toggle('a', '2026-10-13'); // 앱은 이미 체크된 걸 뒤집어 해제해야 한다
      final check = RoutineRepository(await StorageService.create());
      await check.load();
      expect(check.isDone('a', '2026-10-13'), isFalse);
    });

    test('주중에 종료한 주 N회 루틴은 종료일 이전의 마지막 미체크 날을 미달로 센다', () async {
      final repo = await emptyRoutine();
      // 10-05(월) 시작, 주 3회, 10-07(수) 종료, 완료 0회
      await repo.addHabit(habit('a', start: '2026-10-05', repeat: const RepeatRule(type: RepeatType.weekly, times: 3))
          .copyWith(finishedOn: '2026-10-07'));
      final an = RoutineAnalyzer(repo, today: () => today);
      final h = repo.habitById('a')!;
      expect(an.isDue(h, '2026-10-11'), isFalse, reason: '종료일 이후는 대상이 아니다');
      expect(an.isDue(h, '2026-10-07'), isTrue, reason: '종료일까지의 마지막 미체크 날이 미달 1일');
      expect(an.isDue(h, '2026-10-06'), isFalse);
    });

    test('범위를 벗어난 반복 값이 든 백업은 안전한 값으로 걸러진다', () {
      final r = RepeatRule.fromJson({
        'type': 'weekdays',
        'days': [0, 3, 7, -1],
        'times': 99,
        'every': 0,
        'monthDays': [0, 15, 32],
      });
      expect(r.days, [0, 3]);
      expect(r.times, 7);
      expect(r.every, 1);
      expect(r.monthDays, [15]);
      expect(r.summary, isNotEmpty); // 요일 번호 7이 남아 있으면 요약 생성이 범위를 벗어난다
    });

    test('주 목표 미달 표시일은 그 날 다른 모드였던 날을 건너뛴다', () async {
      final repo = await emptyRoutine();
      await repo.addMode('주말');
      final weekend = repo.modes.last.id;
      // 주 3회, 주말 모드 전용. 10-05~10-07은 주말 모드, 10-08부터 기본 모드
      await repo.addHabit(habit('a', start: '2026-09-01', modes: [weekend], repeat: const RepeatRule(type: RepeatType.weekly, times: 3)));
      await repo.setActiveMode(weekend, from: '2026-09-01');
      await repo.setActiveMode(repo.modes.first.id, from: '2026-10-08');
      await repo.setDone('a', '2026-10-05', true);
      final an = RoutineAnalyzer(repo, today: () => today);
      final h = repo.habitById('a')!;
      expect(an.isDue(h, '2026-10-11'), isFalse, reason: '그 날은 다른 모드라 미달 표시일이 될 수 없다');
      expect(an.isDue(h, '2026-10-07'), isTrue, reason: '주말 모드였던 마지막 미체크 날이 미달 1일');
    });

    test('개인 연속 일수는 다른 모드였던 날에 끊기지 않는다', () async {
      final repo = await emptyRoutine();
      await repo.addMode('주말');
      final weekend = repo.modes.last.id;
      await repo.addHabit(habit('w', start: '2026-10-01', modes: [weekend]));
      await repo.setActiveMode(weekend, from: '2026-10-01');
      await repo.setActiveMode(repo.modes.first.id, from: '2026-10-12'); // 10-12, 13은 기본 모드
      await repo.setActiveMode(weekend, from: '2026-10-14');
      await repo.setDone('w', '2026-10-14', true);
      await repo.setDone('w', '2026-10-11', true);
      await repo.setDone('w', '2026-10-10', true);
      final an = RoutineAnalyzer(repo, today: () => today);
      expect(an.habitStreak(repo.habitById('w')!), 3, reason: '기본 모드였던 12, 13일은 건너뛴다');
    });

    test('주 목표 미달 표시는 일요일에 완료했어도 체크하지 않은 마지막 날 하루에 붙는다', () async {
      final repo = await emptyRoutine();
      await repo.addHabit(habit('a', start: '2026-09-01', repeat: const RepeatRule(type: RepeatType.weekly, times: 3)));
      await repo.setDone('a', '2026-10-11', true); // 지난주 일요일에만 1회
      final an = RoutineAnalyzer(repo, today: () => today);
      final h = repo.habitById('a')!;
      expect(an.isDue(h, '2026-10-11'), isTrue, reason: '체크한 날은 계속 표시');
      expect(an.isDue(h, '2026-10-10'), isTrue, reason: '체크하지 않은 마지막 날(토)이 미달 1일');
      expect(an.isDue(h, '2026-10-09'), isFalse);
      expect(an.dayStat('2026-10-10').due, 0, reason: '주간 루틴은 매일 달성률에 들어가지 않는다');
    });

    test('주가 끝났는데 주 목표를 못 채우면 그 주의 일요일이 미달 1일로 센다', () async {
      final repo = await emptyRoutine();
      await repo.addHabit(habit('a', start: '2026-09-01', repeat: const RepeatRule(type: RepeatType.weekly, times: 3)));
      await repo.setDone('a', '2026-10-06', true); // 지난주(10-05 월요일 시작)에 1회만
      final an = RoutineAnalyzer(repo, today: () => today);
      final h = repo.habitById('a')!;
      expect(an.isDue(h, '2026-10-07'), isFalse, reason: '중간 날은 여전히 실패로 세지 않는다');
      expect(an.isDue(h, '2026-10-11'), isTrue, reason: '지난 일요일은 미달 1일');
      expect(an.weeklyProgress(h, '2026-10-11').achieved, isFalse, reason: '지난주 1/3');

      await repo.setDone('a', '2026-10-08', true);
      await repo.setDone('a', '2026-10-09', true); // 3회 달성
      expect(an.isDue(h, '2026-10-11'), isFalse, reason: '목표를 채우면 미달이 아니다');
    });
  });

  group('주간 루틴', () {
    test('주 목표 횟수와 7일 체크 상태를 센다', () async {
      final repo = await emptyRoutine();
      await repo.addHabit(habit('a', start: '2026-09-01', repeat: const RepeatRule(type: RepeatType.weekly, times: 3)));
      await repo.setDone('a', '2026-10-12', true);
      await repo.setDone('a', '2026-10-14', true);
      final an = RoutineAnalyzer(repo, today: () => today);
      final p = an.weeklyProgress(repo.habitById('a')!, today);
      expect(p.days.length, 7);
      expect(p.doneCount, 2);
      expect(p.goal, 3);
      expect(p.remaining, 1);
      expect(p.achieved, isFalse);
      expect(p.days.first.date, '2026-10-12');
      expect(p.days.where((d) => d.future).length, 4, reason: '오늘(수) 뒤 4일은 미래');
      await repo.setDone('a', '2026-10-13', true);
      expect(an.weeklyProgress(repo.habitById('a')!, today).achieved, isTrue);
    });

    test('주간 루틴은 매일 루틴 목록과 달성률에서 빠지고 주간 목록에만 나온다', () async {
      final repo = await emptyRoutine();
      await repo.addHabit(habit('d'));
      await repo.addHabit(habit('w', repeat: const RepeatRule(type: RepeatType.weekly, times: 2)));
      final an = RoutineAnalyzer(repo, today: () => today);
      expect(an.dueHabits(today).map((h) => h.id), ['d']);
      expect(an.weeklyHabits(today).map((h) => h.id), ['w']);
      expect(an.dayStat(today).due, 1);
    });

    test('종료한 주 이후의 주간 루틴은 목록에서 빠진다', () async {
      final repo = await emptyRoutine();
      await repo.addHabit(habit('w', start: '2026-09-01', repeat: const RepeatRule(type: RepeatType.weekly, times: 2))
          .copyWith(finishedOn: '2026-10-07'));
      final an = RoutineAnalyzer(repo, today: () => today);
      expect(an.weeklyHabits('2026-10-07').length, 1, reason: '종료일이 속한 주까지는 보인다');
      expect(an.weeklyHabits('2026-10-14'), isEmpty);
    });
  });

  group('루틴 모드', () {
    test('모드가 지정된 루틴은 그 모드에서만 나온다', () async {
      final repo = await emptyRoutine();
      await repo.addMode('출근 없는 날');
      final other = repo.modes.last.id;
      await repo.addHabit(habit('a', modes: [other]));
      await repo.addHabit(habit('b'));
      final an = RoutineAnalyzer(repo, today: () => today);
      expect(an.dueHabits(today).map((h) => h.id), ['b']);
      await repo.setActiveMode(other);
      expect(an.dueHabits(today).map((h) => h.id), ['a', 'b']);
    });
  });
}
