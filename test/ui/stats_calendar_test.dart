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

    test('완료 숨기기로 감춘 투두도 통계 캘린더와 합계에는 그대로 남고, 통계에서 미완료로 돌리면 다시 보인다', () async {
      final s = await _setup();
      final a = await s.journal.addTodo('끝낸 일', '2026-10-05', done: true);
      await s.journal.addTodo('남은 일', '2026-10-05');
      await s.journal.hideTodos({a.id});
      expect(s.journal.visibleTodos.map((t) => t.text), ['남은 일']);
      expect(s.vm.todoMonthTotals, (done: 1, total: 2), reason: '감춘 완료 투두도 통계에 센다');
      expect(_todoDay(s.vm, 5).done, 1);
      expect(s.vm.todosOn('2026-10-05').length, 2, reason: '그날 목록에도 보인다');
      await s.vm.toggleTodo(s.vm.todosOn('2026-10-05').firstWhere((t) => t.id == a.id)); // 미완료로 돌림
      final back = s.journal.todos.firstWhere((t) => t.id == a.id);
      expect((back.done, back.hidden), (false, false), reason: '미완료로 돌리면 목록에 다시 나타난다');
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

  testWidgets('캘린더 제목을 눌러 연도와 월을 자유롭게 골라 이동한다', (tester) async {
    final s = await _setup();
    await s.journal.addTodo('옛날 일', '2024-03-10');
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider.value(value: s.vm, child: const StatsScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('2026년 10월 캘린더'), findsOneWidget);

    await tester.tap(find.text('2026년 10월 캘린더'));
    await tester.pumpAndSettle();
    expect(find.text('2026년'), findsOneWidget);
    await tester.tap(find.byTooltip('이전 해'));
    await tester.tap(find.byTooltip('이전 해'));
    await tester.pumpAndSettle();
    expect(find.text('2024년'), findsOneWidget);
    await tester.tap(find.text('3월'));
    await tester.pumpAndSettle();

    expect(s.vm.calendarMonth, DateTime(2024, 3));
    expect(find.text('2024년 3월 캘린더'), findsOneWidget);
    expect(find.textContaining('이 달 투두 0/1 완료'), findsOneWidget, reason: '골라서 이동한 달의 투두가 보인다');

    // 취소하면 그대로, 이번 달 버튼은 오늘이 속한 달로 돌아온다
    await tester.tap(find.text('2024년 3월 캘린더'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(s.vm.calendarMonth, DateTime(2024, 3));
    await tester.tap(find.text('2024년 3월 캘린더'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('이번 달')));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    expect(s.vm.calendarMonth, DateTime(now.year, now.month));
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
    // 캘린더 섹션은 하나이고 탭(투두, 계획, 무드)으로 고른다. 처음에는 투두 캘린더가 보인다
    expect(find.textContaining('월 캘린더'), findsOneWidget);
    expect(find.text('투두'), findsOneWidget);
    expect(find.text('계획'), findsOneWidget);
    expect(find.text('무드'), findsOneWidget);
    expect(find.textContaining('월간 계획'), findsNothing, reason: '계획 캘린더는 계획 탭을 눌러야 보인다');
    expect(find.textContaining('이 달 투두 1/2 완료'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);

    await tester.tap(find.text('1/2'));
    await tester.pumpAndSettle();
    expect(find.text('치과'), findsOneWidget);
    expect(find.text('장보기'), findsOneWidget);
    await tester.tap(find.text('장보기'));
    await tester.pumpAndSettle();
    expect(s.journal.todos.every((t) => t.done), isTrue, reason: '시트에서 체크하면 투두가 완료로 바뀐다');
    await tester.tapAt(const Offset(10, 10)); // 시트 닫기
    await tester.pumpAndSettle();

    await tester.tap(find.text('계획'));
    await tester.pumpAndSettle();
    expect(find.textContaining('월간 계획'), findsOneWidget);
    expect(find.textContaining('이 달 투두'), findsNothing, reason: '탭을 바꾸면 투두 캘린더는 숨는다');

    await tester.tap(find.text('무드'));
    await tester.pumpAndSettle();
    expect(find.textContaining('월간 계획'), findsNothing);
    expect(find.text('월'), findsWidgets, reason: '무드 캘린더의 요일 머리글');
  });
}
