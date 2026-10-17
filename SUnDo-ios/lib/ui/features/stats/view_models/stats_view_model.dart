import '../../../../data/repositories/journal_repository.dart';
import '../../../../data/repositories/routine_repository.dart';
import '../../../../domain/models/date_key.dart';
import '../../../../domain/models/journal_models.dart';
import '../../../../domain/use_cases/routine_analyzer.dart';
import '../../../../domain/use_cases/stats_use_case.dart';
import '../../../core/repo_view_model.dart';

class BadgeInfo {
  const BadgeInfo(this.label, this.earned);
  final String label;
  final bool earned;
}

/// 달력 한 칸의 상태. 투두는 끝낸 것과 전체 개수, 계획은 그 주 주간 계획의 평균 진행률로 색을 정한다.
enum CalendarTone { none, done, partial, missed, pending }

/// 통계 화면의 캘린더 섹션에서 고르는 탭.
enum StatsCalendarTab { todo, plan, mood }

extension StatsCalendarTabLabel on StatsCalendarTab {
  String get label => switch (this) {
        StatsCalendarTab.todo => '투두',
        StatsCalendarTab.plan => '계획',
        StatsCalendarTab.mood => '무드',
      };
}

class TodoDayStat {
  const TodoDayStat({required this.date, required this.day, required this.done, required this.total, required this.tone});
  final String date;
  final int day;
  final int done;
  final int total;
  final CalendarTone tone;
}

class PlanDayStat {
  const PlanDayStat({required this.date, required this.day, required this.goalCount, required this.progress, required this.tone});
  final String date;
  final int day;
  final int goalCount; // 그 날을 덮는 주간 계획 개수
  final double progress; // 그 주 주간 계획들의 평균 진행률(0~1)
  final CalendarTone tone;
}

class StatsViewModel extends RepoViewModel {
  StatsViewModel({
    required RoutineRepository routine,
    required JournalRepository journal,
    required RoutineAnalyzer analyzer,
    required StatsUseCase stats,
  })  : _routine = routine,
        _journal = journal,
        _analyzer = analyzer,
        _stats = stats,
        calendarMonth = DateTime(DateTime.now().year, DateTime.now().month),
        super([routine, journal]);

  final RoutineRepository _routine;
  final JournalRepository _journal;
  final RoutineAnalyzer _analyzer;
  final StatsUseCase _stats;

  StatsRange range = StatsRange.rolling7;
  StatsCalendarTab calendarTab = StatsCalendarTab.todo;
  DateTime calendarMonth;

  StatsSummary get summary => _stats.summarize(range);

  void setCalendarTab(StatsCalendarTab t) {
    calendarTab = t;
    notifyListeners();
  }

  void setRange(StatsRange r) {
    range = r;
    notifyListeners();
  }

  void shiftMonth(int delta) {
    calendarMonth = DateTime(calendarMonth.year, calendarMonth.month + delta);
    notifyListeners();
  }

  /// 달력 칸 목록: 앞쪽 빈칸은 null.
  List<({int day, int mood})?> get moodCalendar {
    final first = DateTime(calendarMonth.year, calendarMonth.month, 1);
    final len = DateTime(calendarMonth.year, calendarMonth.month + 1, 0).day;
    return [
      for (var i = 0; i < first.weekday % 7; i++) null,
      for (var d = 1; d <= len; d++)
        (day: d, mood: _journal.reviewOf(dateKey(DateTime(calendarMonth.year, calendarMonth.month, d))).mood),
    ];
  }

  String _dayKey(int d) => dateKey(DateTime(calendarMonth.year, calendarMonth.month, d));

  int get _monthLength => DateTime(calendarMonth.year, calendarMonth.month + 1, 0).day;

  /// 일요일 시작 달력 앞쪽의 빈칸 수.
  int get _leadingBlanks => DateTime(calendarMonth.year, calendarMonth.month, 1).weekday % 7;

  /// 투두 달력: 날마다 끝낸 개수와 전체 개수. 앞쪽 빈칸은 null.
  List<TodoDayStat?> get todoCalendar {
    final today = todayKey();
    final byDate = <String, List<Todo>>{};
    for (final t in _journal.todos) {
      byDate.putIfAbsent(t.date, () => []).add(t);
    }
    return [
      for (var i = 0; i < _leadingBlanks; i++) null,
      for (var d = 1; d <= _monthLength; d++)
        () {
          final key = _dayKey(d);
          final list = byDate[key] ?? const <Todo>[];
          final done = list.where((t) => t.done).length;
          final tone = list.isEmpty
              ? CalendarTone.none
              : done == list.length
                  ? CalendarTone.done
                  : done > 0
                      ? CalendarTone.partial
                      : (key.compareTo(today) < 0 ? CalendarTone.missed : CalendarTone.pending);
          return TodoDayStat(date: key, day: d, done: done, total: list.length, tone: tone);
        }(),
    ];
  }

  /// 이번 달 투두 합계(끝낸 개수, 전체 개수).
  ({int done, int total}) get todoMonthTotals {
    var done = 0, total = 0;
    for (final c in todoCalendar) {
      if (c == null) continue;
      done += c.done;
      total += c.total;
    }
    return (done: done, total: total);
  }

  /// 그 날의 투두(시간 있는 것을 시간 순으로 먼저).
  List<Todo> todosOn(String date) => sortTodos(_journal.todos.where((t) => t.date == date));

  Future<void> toggleTodo(Todo t) => _journal.updateTodo(t.copyWith(done: !t.done));

  /// 그 날을 덮는 계획: 그 주 주간 계획, 그 달 월간 계획, 그 해 연간 계획.
  List<Goal> goalsCovering(String date) {
    final d = parseDateKey(date);
    return [
      ..._journal.goalsFor(GoalPeriod.week, weekStartKey(date)),
      ..._journal.goalsFor(GoalPeriod.month, '${d.year}-${d.month.toString().padLeft(2, '0')}'),
      ..._journal.goalsFor(GoalPeriod.year, '${d.year}'),
    ];
  }

  /// 계획 달력: 날마다 그 주 주간 계획의 평균 진행률. 주간 계획이 없는 날은 비워 둔다.
  List<PlanDayStat?> get planCalendar {
    final today = todayKey();
    return [
      for (var i = 0; i < _leadingBlanks; i++) null,
      for (var d = 1; d <= _monthLength; d++)
        () {
          final key = _dayKey(d);
          final weekly = _journal.goalsFor(GoalPeriod.week, weekStartKey(key));
          final p = weekly.isEmpty ? 0.0 : weekly.fold(0.0, (a, g) => a + g.progress) / weekly.length;
          final tone = weekly.isEmpty
              ? CalendarTone.none
              : p >= 1
                  ? CalendarTone.done
                  : p > 0
                      ? CalendarTone.partial
                      : (key.compareTo(today) < 0 ? CalendarTone.missed : CalendarTone.pending);
          return PlanDayStat(date: key, day: d, goalCount: weekly.length, progress: p, tone: tone);
        }(),
    ];
  }

  /// 보고 있는 달의 월간 계획 평균 진행률. 월간 계획이 없으면 null.
  double? get monthGoalProgress => _avgProgress(_journal.goalsFor(GoalPeriod.month,
      '${calendarMonth.year}-${calendarMonth.month.toString().padLeft(2, '0')}'));

  /// 보고 있는 해의 연간 계획 평균 진행률. 연간 계획이 없으면 null.
  double? get yearGoalProgress => _avgProgress(_journal.goalsFor(GoalPeriod.year, '${calendarMonth.year}'));

  static double? _avgProgress(List<Goal> g) =>
      g.isEmpty ? null : g.fold(0.0, (a, x) => a + x.progress) / g.length;

  List<BadgeInfo> get badges {
    final total = _routine.totalChecks;
    final s = _analyzer.streak();
    final reviews = _journal.reviewDays;
    return [
      BadgeInfo('🌱 첫 체크', total >= 1),
      BadgeInfo('🔥 3일 연속', s >= 3),
      BadgeInfo('🔥 7일 연속', s >= 7),
      BadgeInfo('🏅 30일 연속', s >= 30),
      BadgeInfo('👑 100일 연속', s >= 100),
      BadgeInfo('✅ 100회 체크', total >= 100),
      BadgeInfo('✅ 500회 체크', total >= 500),
      BadgeInfo('✅ 1000회 체크', total >= 1000),
      BadgeInfo('✏️ 회고 7일', reviews >= 7),
      BadgeInfo('✏️ 회고 30일', reviews >= 30),
    ];
  }

  int get totalChecks => _routine.totalChecks;
  int get streak => _analyzer.streak();
  int get routineDay => _analyzer.routineDay;

  /// 루틴 레벨: 누적 체크 수에 따라 오른다.
  ({String emoji, String name, int next}) get level {
    final t = totalChecks;
    const steps = [(0, '🌱', '새싹'), (50, '🌿', '풀잎'), (200, '🌳', '나무'), (600, '🌸', '꽃'), (1500, '👑', '왕관')];
    var idx = 0;
    for (var i = 0; i < steps.length; i++) {
      if (t >= steps[i].$1) idx = i;
    }
    final next = idx + 1 < steps.length ? steps[idx + 1].$1 : steps[idx].$1;
    return (emoji: steps[idx].$2, name: steps[idx].$3, next: next);
  }
}
