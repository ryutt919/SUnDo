import '../../data/repositories/routine_repository.dart';
import '../models/date_key.dart';
import '../models/habit.dart';
import '../models/repeat_rule.dart';

enum TrafficLight { none, green, yellow, red, rest }

class DayStat {
  const DayStat({required this.rest, required this.due, required this.done});
  final bool rest;
  final int due;
  final int done;

  /// 해야 할 습관이 없거나 쉬는 날이면 null.
  double? get rate => (rest || due == 0) ? null : done / due;
}

/// 날짜별 해야 할 습관, 달성률, 신호등, 연속 일수를 계산한다.
/// 신호등 기준: 60% 이상 초록, 20% 이상 노랑, 그 미만 빨강.
class RoutineAnalyzer {
  RoutineAnalyzer(this._routine, {String Function()? today}) : _today = today ?? todayKey;

  final RoutineRepository _routine;
  final String Function() _today;

  static const greenAt = 0.6;
  static const yellowAt = 0.2;

  String get today => _today();

  bool inActiveMode(Habit h) => h.modes.isEmpty || h.modes.contains(_routine.activeModeId);

  int _weekDoneCount(Habit h, String date) {
    final ws = weekStartKey(date);
    var c = 0;
    for (var i = 0; i < 7; i++) {
      if (_routine.isDone(h.id, addDaysKey(ws, i))) c++;
    }
    return c;
  }

  bool isDue(Habit h, String date) {
    if (h.archived || date.compareTo(h.start) < 0) return false;
    final fin = h.finishedOn;
    if (fin != null && date.compareTo(fin) > 0) return false;
    final r = h.repeat;
    switch (r.type) {
      case RepeatType.daily:
        return true;
      case RepeatType.weekdays:
        return r.days.contains(sundayZero(parseDateKey(date)));
      case RepeatType.interval:
        final diff = daysBetween(h.start, date);
        return diff >= 0 && diff % (r.every < 1 ? 1 : r.every) == 0;
      case RepeatType.monthDays:
        return r.monthDays.contains(parseDateKey(date).day);
      case RepeatType.weekly:
        if (_routine.isDone(h.id, date)) return true;
        if (date.compareTo(today) < 0) return false; // 지난 날 미체크는 실패로 세지 않는다
        return _weekDoneCount(h, date) < r.times;
    }
  }

  List<Habit> dueHabits(String date) => [
        for (final h in _routine.habits)
          if (inActiveMode(h) && isDue(h, date)) h
      ];

  DayStat dayStat(String date) {
    if (_routine.isRest(date)) return const DayStat(rest: true, due: 0, done: 0);
    final list = dueHabits(date);
    final done = list.where((h) => _routine.isDone(h.id, date)).length;
    return DayStat(rest: false, due: list.length, done: done);
  }

  TrafficLight lightOf(DayStat s, String date) {
    if (s.rest) return TrafficLight.rest;
    final rate = s.rate;
    if (rate == null || date.compareTo(today) > 0) return TrafficLight.none;
    if (date == today && rate == 0) return TrafficLight.none; // 오늘은 진행 중
    if (rate >= greenAt) return TrafficLight.green;
    if (rate >= yellowAt) return TrafficLight.yellow;
    return TrafficLight.red;
  }

  String get _firstDate {
    final starts = _routine.habits.map((h) => h.start).toList()..sort();
    return starts.isEmpty ? today : starts.first;
  }

  /// 초록불이 이어진 일수. 쉬는 날과 습관이 없는 날은 건너뛴다.
  int streak() {
    var d = today;
    final s0 = dayStat(d);
    if (!s0.rest && s0.rate != null && s0.rate! < greenAt) d = addDaysKey(d, -1);
    var n = 0;
    final first = _firstDate;
    for (var i = 0; i < 3650; i++, d = addDaysKey(d, -1)) {
      final st = dayStat(d);
      if (st.rest || st.rate == null) {
        if (d.compareTo(first) < 0) break;
        continue;
      }
      if (st.rate! >= greenAt) {
        n++;
      } else {
        break;
      }
    }
    return n;
  }

  /// 한 습관의 연속 달성 일수.
  int habitStreak(Habit h) {
    var d = today;
    if (!_routine.isDone(h.id, d)) d = addDaysKey(d, -1);
    var n = 0;
    for (var i = 0; i < 3650 && d.compareTo(h.start) >= 0; i++, d = addDaysKey(d, -1)) {
      if (_routine.isRest(d)) continue;
      final done = _routine.isDone(h.id, d);
      if (!isDue(h, d) && !done) continue;
      if (done) {
        n++;
      } else {
        break;
      }
    }
    return n;
  }

  /// 처음 습관을 시작한 뒤 지난 일수 (1일차부터).
  int get routineDay => daysBetween(_firstDate, today) + 1;
}
