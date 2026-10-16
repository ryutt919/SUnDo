import '../../data/repositories/routine_repository.dart';
import '../models/date_key.dart';
import '../models/habit.dart';
import 'routine_analyzer.dart';

enum StatsRange { rolling7, rolling30, thisWeek, thisMonth }

extension StatsRangeLabel on StatsRange {
  String get label => switch (this) {
        StatsRange.rolling7 => '최근 7일',
        StatsRange.rolling30 => '최근 30일',
        StatsRange.thisWeek => '이번 주',
        StatsRange.thisMonth => '이번 달',
      };
}

class HabitStat {
  const HabitStat(this.habit, this.due, this.done);
  final Habit habit;
  final int due;
  final int done;
  double get rate => due == 0 ? 0 : done / due;
}

class StatsSummary {
  const StatsSummary({
    required this.dates,
    required this.dayStats,
    required this.lights,
    required this.averageRate,
    required this.greenDays,
    required this.ratedDays,
    required this.habitStats,
  });
  final List<String> dates;
  final List<DayStat> dayStats;
  final List<TrafficLight> lights;
  final double averageRate;
  final int greenDays;
  final int ratedDays;
  final List<HabitStat> habitStats;
}

class StatsUseCase {
  StatsUseCase(this._routine, this._analyzer);

  final RoutineRepository _routine;
  final RoutineAnalyzer _analyzer;

  List<String> datesFor(StatsRange range) {
    final t = _analyzer.today;
    switch (range) {
      case StatsRange.rolling7:
        return [for (var i = 6; i >= 0; i--) addDaysKey(t, -i)];
      case StatsRange.rolling30:
        return [for (var i = 29; i >= 0; i--) addDaysKey(t, -i)];
      case StatsRange.thisWeek:
        final ws = weekStartKey(t);
        return [for (var d = ws; d.compareTo(t) <= 0; d = addDaysKey(d, 1)) d];
      case StatsRange.thisMonth:
        final n = parseDateKey(t);
        final first = dateKey(DateTime(n.year, n.month, 1));
        return [for (var d = first; d.compareTo(t) <= 0; d = addDaysKey(d, 1)) d];
    }
  }

  StatsSummary summarize(StatsRange range) {
    final dates = datesFor(range);
    final stats = dates.map(_analyzer.dayStat).toList();
    final lights = [for (var i = 0; i < dates.length; i++) _analyzer.lightOf(stats[i], dates[i])];
    final rated = stats.where((s) => s.rate != null).toList();
    final avg = rated.isEmpty ? 0.0 : rated.fold(0.0, (a, s) => a + s.rate!) / rated.length;
    final greens = rated.where((s) => s.rate! >= RoutineAnalyzer.greenAt).length;

    final habitStats = <HabitStat>[];
    for (final h in _routine.habits) {
      // 보관한 습관도 보관 전 기간의 통계에는 남긴다(종료일이 없는 보관 습관만 제외).
      if ((h.archived && h.finishedOn == null) || !_analyzer.inActiveMode(h)) continue;
      var due = 0, done = 0;
      for (final d in dates) {
        if (_routine.isRest(d)) continue;
        if (_routine.isDone(h.id, d)) {
          due++;
          done++;
        } else if (_analyzer.isDue(h, d)) {
          due++;
        }
      }
      if (h.archived && due == 0) continue; // 이 기간에 쓰이지 않은 보관 습관은 숨긴다
      habitStats.add(HabitStat(h, due, done));
    }
    return StatsSummary(
      dates: dates,
      dayStats: stats,
      lights: lights,
      averageRate: avg,
      greenDays: greens,
      ratedDays: rated.length,
      habitStats: habitStats,
    );
  }

  /// 수치형 습관의 최근 기록 (날짜, 값) 목록.
  List<(String, double)> valueSeries(String habitId, {int days = 30}) {
    final t = _analyzer.today;
    final out = <(String, double)>[];
    for (var i = days - 1; i >= 0; i--) {
      final d = addDaysKey(t, -i);
      final v = _routine.logOf(habitId, d)?.value;
      if (v != null) out.add((d, v));
    }
    return out;
  }
}
