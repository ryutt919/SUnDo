import '../../../../data/repositories/journal_repository.dart';
import '../../../../data/repositories/routine_repository.dart';
import '../../../../domain/models/date_key.dart';
import '../../../../domain/use_cases/routine_analyzer.dart';
import '../../../../domain/use_cases/stats_use_case.dart';
import '../../../core/repo_view_model.dart';

class BadgeInfo {
  const BadgeInfo(this.label, this.earned);
  final String label;
  final bool earned;
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
  DateTime calendarMonth;

  StatsSummary get summary => _stats.summarize(range);

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
