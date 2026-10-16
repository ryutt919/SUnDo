import 'package:flutter_test/flutter_test.dart';
import 'package:my_routine/data/repositories/journal_repository.dart';
import 'package:my_routine/data/repositories/routine_repository.dart';
import 'package:my_routine/data/repositories/settings_repository.dart';
import 'package:my_routine/data/services/storage_service.dart';
import 'package:my_routine/domain/models/journal_models.dart';
import 'package:my_routine/domain/use_cases/alarm_plan_use_case.dart';
import 'package:my_routine/domain/use_cases/routine_analyzer.dart';
import 'package:my_routine/domain/use_cases/widget_snapshot_use_case.dart';
import 'package:my_routine/ui/features/home/view_models/home_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

const _today = '2026-10-14';

typedef _Setup = ({
  HomeViewModel vm,
  JournalRepository journal,
  RoutineRepository routine,
  RoutineAnalyzer analyzer,
});

Future<_Setup> _setup() async {
  final routine = await emptyRoutine();
  final store = await StorageService.create();
  final journal = JournalRepository(store);
  await journal.load();
  final settings = SettingsRepository(store);
  await settings.load();
  final analyzer = RoutineAnalyzer(routine, today: () => _today);
  final vm = HomeViewModel(routine: routine, journal: journal, settings: settings, analyzer: analyzer);
  return (vm: vm, journal: journal, routine: routine, analyzer: analyzer);
}

void main() {
  test('주간 스트립은 월요일부터 7칸이고 선택한 날이 표시된다', () async {
    final s = await _setup();
    final cells = s.vm.weekCells;
    expect(cells.length, 7);
    expect(cells.first.date, '2026-10-12');
    expect(cells.first.weekdayLabel, '월');
    expect(cells.last.weekdayLabel, '일');
    expect(cells.where((c) => c.selected).single.date, _today);
  });

  test('체크하면 달성률이 오르고 완료 항목은 아래로 내려간다', () async {
    final s = await _setup();
    await s.routine.addHabit(habit('a', name: 'A'));
    await s.routine.addHabit(habit('b', name: 'B'));
    expect(s.vm.percent, 0);
    await s.vm.toggleHabit('a');
    expect(s.vm.percent, 50);
    expect(s.vm.habitRows.map((r) => r.habit.id), ['b', 'a'], reason: '완료 항목은 아래로');
    expect(s.vm.habitRows.last.done, isTrue);
  });

  test('필터는 전체, 미완료, 완료 순으로 돈다', () async {
    final s = await _setup();
    await s.routine.addHabit(habit('a'));
    await s.routine.addHabit(habit('b'));
    await s.vm.toggleHabit('a');
    s.vm.cycleFilter();
    expect(s.vm.habitRows.map((r) => r.habit.id), ['b']);
    s.vm.cycleFilter();
    expect(s.vm.habitRows.map((r) => r.habit.id), ['a']);
    s.vm.cycleFilter();
    expect(s.vm.habitRows.length, 2);
  });

  test('지난 날의 미완료 투두는 오늘로 이월되어 보인다', () async {
    final s = await _setup();
    await s.journal.addTodo('택배 챙기기', '2026-10-10');
    await s.journal.addTodo('끝낸 일', '2026-10-09');
    await s.journal.updateTodo(s.journal.todos.last.copyWith(done: true));
    final rows = s.vm.todoRows;
    expect(rows.map((r) => r.todo.text), ['택배 챙기기']);
    expect(rows.single.carriedFrom, '2026-10-10');
  });

  test('주간 이동은 7일씩 움직인다', () async {
    final s = await _setup();
    s.vm.shiftWeek(1);
    expect(s.vm.selectedDate, '2026-10-21');
    s.vm.shiftWeek(-2);
    expect(s.vm.selectedDate, '2026-10-07');
  });

  test('위젯 데이터는 오늘의 행, 달성률, 주간 7칸을 담는다', () async {
    final s = await _setup();
    await s.routine.addHabit(habit('a', name: 'A'));
    await s.routine.addHabit(habit('b', name: 'B'));
    await s.routine.setDone('a', _today, true);
    final snap = WidgetSnapshotUseCase(s.routine, s.analyzer).build();
    expect(snap['date'], _today);
    expect(snap['pct'], 50);
    expect((snap['rows'] as List).length, 2);
    expect((snap['week'] as List).length, 7);
    expect(((snap['rows'] as List).first as Map)['id'], 'a');
  });

  test('알람은 해야 하는 날에만, 아직 안 한 습관에만 만든다', () async {
    final s = await _setup();
    await s.routine.addHabit(habit('a').copyWith(alarm: '09:00'));
    await s.routine.addHabit(habit('b').copyWith(alarm: '10:00'));
    await s.routine.setDone('b', _today, true);
    await s.routine.setRest('2026-10-15', true);
    final plan = AlarmPlanUseCase(s.routine, s.analyzer).build(now: DateTime(2026, 10, 14, 8, 0));
    final times = plan.map((a) => a.at).toList();
    expect(times.where((d) => d.day == 14).length, 1, reason: '오늘은 b가 완료여서 a만');
    expect(times.where((d) => d.day == 15), isEmpty, reason: '쉬는 날');
    expect(times.where((d) => d.day == 16).length, 2);
  });

  test('아침/저녁 전체 알람은 쉬는 날을 건너뛰고, 아침 알람은 할 습관이 있을 때만 만든다', () async {
    final s = await _setup();
    final plan0 = AlarmPlanUseCase(s.routine, s.analyzer)
        .build(now: DateTime(2026, 10, 14, 6, 0), morning: '08:00', evening: '21:00');
    expect(plan0.where((a) => a.title == '좋은 아침이에요'), isEmpty, reason: '습관이 없으면 아침 알람 없음');
    expect(plan0.where((a) => a.title == '오늘 하루 어땠나요?').length, 14);

    await s.routine.addHabit(habit('a'));
    await s.routine.setRest('2026-10-15', true);
    final plan = AlarmPlanUseCase(s.routine, s.analyzer)
        .build(now: DateTime(2026, 10, 14, 6, 0), morning: '08:00', evening: '21:00');
    expect(plan.where((a) => a.at.day == 15), isEmpty, reason: '쉬는 날');
    expect(plan.where((a) => a.at.day == 14).length, 2);
    final ids = plan.map((a) => a.id).toSet();
    expect(ids.length, plan.length, reason: '알람 ID는 서로 달라야 한다');
  });

  test('시간순 보기는 시각이 있는 습관을 시간 순으로, 없는 습관을 뒤에 둔다', () async {
    final s = await _setup();
    await s.routine.addHabit(habit('late').copyWith(time: '22:00'));
    await s.routine.addHabit(habit('none'));
    await s.routine.addHabit(habit('early').copyWith(time: '07:00'));
    expect(s.vm.habitRows.map((r) => r.habit.id), ['late', 'none', 'early']);
    await s.vm.toggleSortByTime();
    expect(s.vm.habitRows.map((r) => r.habit.id), ['early', 'late', 'none']);
  });

  test('월간 위젯 데이터는 달 길이와 1일의 칸 위치를 담는다', () async {
    final s = await _setup();
    final snap = WidgetSnapshotUseCase(s.routine, s.analyzer).build();
    final month = snap['month'] as Map;
    expect(month['label'], '2026년 10월');
    expect((month['days'] as List).length, 31);
    expect(month['offset'], 3, reason: '2026-10-01은 목요일(월요일 시작 기준 3칸)');
  });

  test('목표 진행률은 완료한 세부 항목 비율이다', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await StorageService.create();
    final journal = JournalRepository(store);
    await journal.load();
    const goal = Goal(
      id: 'g',
      title: '10월 목표',
      period: GoalPeriod.month,
      periodKey: '2026-10',
      items: [GoalItem(text: 'a', done: true), GoalItem(text: 'b')],
    );
    await journal.saveGoal(goal);
    expect(journal.goalsFor(GoalPeriod.month, '2026-10').single.progress, 0.5);
  });
}
