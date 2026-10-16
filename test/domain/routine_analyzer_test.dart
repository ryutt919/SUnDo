import 'package:flutter_test/flutter_test.dart';
import 'package:my_routine/domain/models/repeat_rule.dart';
import 'package:my_routine/domain/use_cases/routine_analyzer.dart';

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

  group('루틴 모드', () {
    test('모드가 지정된 습관은 그 모드에서만 나온다', () async {
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
