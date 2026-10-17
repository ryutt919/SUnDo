import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_routine/data/repositories/journal_repository.dart';
import 'package:my_routine/data/services/storage_service.dart';
import 'package:my_routine/domain/models/date_key.dart';
import 'package:my_routine/domain/models/journal_models.dart';
import 'package:my_routine/domain/use_cases/routine_analyzer.dart';
import 'package:my_routine/domain/use_cases/stats_use_case.dart';
import 'package:my_routine/ui/features/stats/view_models/stats_view_model.dart';
import 'package:my_routine/ui/features/stats/views/stats_screen.dart';
import 'package:provider/provider.dart';

import '../test_helpers.dart';

const _today = '2026-10-14'; // 수요일

Future<({StatsViewModel vm, JournalRepository journal})> _setup() async {
  final routine = await emptyRoutine();
  final store = await StorageService.create();
  final journal = JournalRepository(store);
  await journal.load();
  final analyzer = RoutineAnalyzer(routine, today: () => _today);
  final vm = StatsViewModel(
    routine: routine,
    journal: journal,
    analyzer: analyzer,
    stats: StatsUseCase(routine, analyzer),
  )..calendarMonth = DateTime(2026, 10);
  return (vm: vm, journal: journal);
}

TodoDayStat _todoDay(StatsViewModel vm, int day) => vm.todoCalendar.whereType<TodoDayStat>().firstWhere((c) => c.day == day);
PlanDayStat _planDay(StatsViewModel vm, int day) => vm.planCalendar.whereType<PlanDayStat>().firstWhere((c) => c.day == day);

void main() {
  group('투두 캘린더', () {
    test('앞쪽 빈칸과 달 길이', () async {
      final s = await _setup();
      final cal = s.vm.todoCalendar;
      expect(cal.where((c) => c == null).length, 4, reason: '2026-10-01은 목요일이라 일요일 시작 달력 앞에 4칸이 빈다');
      expect(cal.whereType<TodoDayStat>().length, 31);
    });

    test('날짜가 아직 오지 않은 미완료 투두는 예정, 다 끝낸 날은 모두 완료', () async {
      final s = await _setup();
      s.vm.calendarMonth = DateTime(2099, 10);
      await s.journal.addTodo('먼 미래', '2099-10-08');
      await s.journal.addTodo('미리 끝냄', '2099-10-09', done: true);
      expect(_todoDay(s.vm, 8).tone, CalendarTone.pending);
      expect((_todoDay(s.vm, 8).done, _todoDay(s.vm, 8).total), (0, 1));
      expect(_todoDay(s.vm, 9).tone, CalendarTone.done);
    });

    test('이 달 합계와 하루 목록, 완료 토글', () async {
      final s = await _setup();
      await s.journal.addTodo('a', '2026-10-05', done: true, time: '10:00');
      await s.journal.addTodo('b', '2026-10-05');
      await s.journal.addTodo('c', '2026-11-01', done: true);
      expect(s.vm.todoMonthTotals, (done: 1, total: 2), reason: '다른 달 투두는 합계에 넣지 않는다');
      expect(s.vm.todosOn('2026-10-05').map((t) => t.text), ['a', 'b'], reason: '시간 있는 것이 먼저');
      await s.vm.toggleTodo(s.vm.todosOn('2026-10-05').last);
      expect(s.vm.todoMonthTotals, (done: 2, total: 2));
      expect(_todoDay(s.vm, 5).tone, CalendarTone.done);
    });

    test('날짜가 지난 미완료 투두만 있으면 못 한 날, 일부만 하면 일부 완료', () async {
      final s = await _setup();
      s.vm.calendarMonth = DateTime(2020, 1);
      await s.journal.addTodo('옛날 일', '2020-01-10');
      await s.journal.addTodo('옛날 일2', '2020-01-11', done: true);
      await s.journal.addTodo('옛날 일3', '2020-01-11');
      expect(_todoDay(s.vm, 10).tone, CalendarTone.missed);
      expect(_todoDay(s.vm, 11).tone, CalendarTone.partial);
      expect(_todoDay(s.vm, 12).tone, CalendarTone.none);
    });
  });

  group('계획 캘린더', () {
    test('주간 계획이 있는 주의 모든 날이 그 주 평균 진행률로 칠해진다', () async {
      final s = await _setup();
      // 2026-10-12(월)~10-18(일) 주
      await s.journal.saveGoal(const Goal(id: 'g1', title: '운동', period: GoalPeriod.week, periodKey: '2026-10-12', done: true));
      await s.journal.saveGoal(const Goal(
        id: 'g2',
        title: '독서',
        period: GoalPeriod.week,
        periodKey: '2026-10-12',
        items: [GoalItem(text: 'a', done: true), GoalItem(text: 'b')],
      ));
      for (final d in [12, 15, 18]) {
        final c = _planDay(s.vm, d);
        expect(c.goalCount, 2);
        expect(c.progress, closeTo(0.75, 1e-9));
        expect(c.tone, CalendarTone.partial);
      }
      expect(_planDay(s.vm, 11).goalCount, 0, reason: '전 주에는 계획이 없다');
      expect(_planDay(s.vm, 11).tone, CalendarTone.none);
      expect(_planDay(s.vm, 19).tone, CalendarTone.none);
    });

    test('모두 달성한 주는 초록, 월간과 연간 계획은 따로 평균을 낸다', () async {
      final s = await _setup();
      await s.journal.saveGoal(const Goal(id: 'w', title: 'w', period: GoalPeriod.week, periodKey: '2026-10-05', done: true));
      await s.journal.saveGoal(const Goal(id: 'm', title: 'm', period: GoalPeriod.month, periodKey: '2026-10', items: [GoalItem(text: 'a', done: true), GoalItem(text: 'b')]));
      await s.journal.saveGoal(const Goal(id: 'y', title: 'y', period: GoalPeriod.year, periodKey: '2026', done: true));
      expect(_planDay(s.vm, 6).tone, CalendarTone.done);
      expect(s.vm.monthGoalProgress, 0.5);
      expect(s.vm.yearGoalProgress, 1.0);
      s.vm.shiftMonth(1);
      expect(s.vm.monthGoalProgress, isNull, reason: '다음 달에는 월간 계획이 없다');
      expect(s.vm.yearGoalProgress, 1.0);
    });

    test('그 날을 덮는 계획은 그 주 주간, 그 달 월간, 그 해 연간 순서', () async {
      final s = await _setup();
      await s.journal.saveGoal(const Goal(id: 'y', title: '연', period: GoalPeriod.year, periodKey: '2026'));
      await s.journal.saveGoal(const Goal(id: 'm', title: '월', period: GoalPeriod.month, periodKey: '2026-10'));
      await s.journal.saveGoal(const Goal(id: 'w', title: '주', period: GoalPeriod.week, periodKey: '2026-10-12'));
      await s.journal.saveGoal(const Goal(id: 'w2', title: '다른 주', period: GoalPeriod.week, periodKey: '2026-10-05'));
      expect(s.vm.goalsCovering('2026-10-14').map((g) => g.title), ['주', '월', '연']);
      expect(s.vm.goalsCovering('2026-11-14').map((g) => g.title), ['연']);
    });
  });

  testWidgets('통계 화면에 투두와 계획 캘린더가 달력으로 나오고, 칸을 누르면 그날 내용이 보인다', (tester) async {
    final s = await _setup();
    s.vm.calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
    final today = todayKey();
    await s.journal.addTodo('치과', today, done: true);
    await s.journal.addTodo('장보기', today);
    final ws = weekStartKey(today);
    await s.journal.saveGoal(Goal(id: 'g', title: '운동 3번', period: GoalPeriod.week, periodKey: ws));
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider.value(value: s.vm, child: const StatsScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('투두 캘린더'), findsOneWidget);
    expect(find.textContaining('계획 캘린더'), findsOneWidget);
    expect(find.textContaining('이 달 투두 1/2 완료'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);

    await tester.tap(find.text('1/2'));
    await tester.pumpAndSettle();
    expect(find.text('치과'), findsOneWidget);
    expect(find.text('장보기'), findsOneWidget);
    await tester.tap(find.text('장보기'));
    await tester.pumpAndSettle();
    expect(s.journal.todos.every((t) => t.done), isTrue, reason: '시트에서 체크하면 투두가 완료로 바뀐다');
  });
}
