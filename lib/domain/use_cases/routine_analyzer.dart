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

  /// [date]에 이 습관이 현재 루틴 모드에 속하는지. 오늘 이후는 현재 모드, 지난 날은 그날 쓰던 모드(이력)를 쓴다.
  /// 그래서 모드를 바꿔도 지난 날의 달성률과 신호등은 변하지 않는다. [date]를 생략하면 현재 모드 기준.
  bool inActiveMode(Habit h, [String? date]) {
    if (h.modes.isEmpty) return true;
    final current = date == null || date.compareTo(today) >= 0;
    final mode = current ? _routine.activeModeId : _routine.modeOn(date);
    if (h.modes.contains(mode)) return true;
    // 소속 모드가 모두 삭제된 습관은 마지막 모드를 삭제한 날부터 모든 모드에 나타난다.
    // 삭제 전 날짜는 그때의 모드 구성을 그대로 따른다(과거 달성률과 신호등이 변하지 않게).
    if (h.modes.every((m) => !_routine.hasMode(m))) {
      var since = '0000-01-01';
      for (final m in h.modes) {
        final d = _routine.modeDeletedOn(m);
        if (d != null && d.compareTo(since) > 0) since = d;
      }
      return (date ?? today).compareTo(since) >= 0;
    }
    return false;
  }

  int _weekDoneCount(Habit h, String date) {
    final ws = weekStartKey(date);
    var c = 0;
    for (var i = 0; i < 7; i++) {
      if (_routine.isDone(h.id, addDaysKey(ws, i))) c++;
    }
    return c;
  }

  bool isDue(Habit h, String date) {
    // 보관하면 finishedOn이 정해져서 보관한 날 이후만 사라지고 과거 기록과 신호등은 그대로 남는다.
    if ((h.archived && h.finishedOn == null) || date.compareTo(h.start) < 0) return false;
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
        if (date.compareTo(today) < 0) return _isWeeklyMissDay(h, date);
        return _weekDoneCount(h, date) < r.times;
    }
  }

  /// 주 N회 습관의 지난 날(체크하지 않은 날)을 미달로 셀지 정한다.
  /// 지난 날의 미체크를 하루하루 실패로 세지는 않고, 주가 끝난 뒤 주 목표를 못 채웠으면
  /// 그 주에서 체크하지 않은 마지막 날 하루만 미달 1일로 센다. 통계와 연속 일수에 반영된다.
  bool _isWeeklyMissDay(Habit h, String date) {
    final ws = weekStartKey(date);
    final we = addDaysKey(ws, 6);
    if (we.compareTo(today) >= 0) return false; // 아직 끝나지 않은 주
    if (_weekDoneCount(h, date) >= h.repeat.times) return false;
    for (var d = we; d.compareTo(ws) >= 0; d = addDaysKey(d, -1)) {
      if (d.compareTo(h.start) < 0) break;
      final fin = h.finishedOn;
      if (fin != null && d.compareTo(fin) > 0) continue; // 종료한 날 이후는 미달 표시일이 될 수 없다
      // 쉬는 날이거나 그 날 다른 모드였던 날은 미달 표시일로 삼지 않는다
      if (_routine.isDone(h.id, d) || _routine.isRest(d) || !inActiveMode(h, d)) continue;
      return d == date;
    }
    return false;
  }

  List<Habit> dueHabits(String date) => [
        for (final h in _routine.habits)
          if (inActiveMode(h, date) && isDue(h, date)) h
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
      if (!inActiveMode(h, d)) continue; // 그 날 쓰던 모드에 속하지 않았으면 끊지 않고 건너뛴다
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
