import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/routine_repository.dart';

class _RunningTimer {
  _RunningTimer(this.secondsLeft);
  int secondsLeft;
  Timer? ticker;
  bool finished = false;
}

/// 습관별 타이머를 앱이 살아 있는 동안 유지한다.
/// 상세 시트를 닫았다 다시 열어도 남은 시간이 이어지고, 끝나면 그 날의 습관을 완료로 체크한다.
class HabitTimerManager extends ChangeNotifier {
  HabitTimerManager(this._routine);

  final RoutineRepository _routine;
  final Map<String, _RunningTimer> _timers = {};

  static String keyOf(String habitId, String date) => '$habitId|$date';

  int? secondsLeft(String habitId, String date) => _timers[keyOf(habitId, date)]?.secondsLeft;

  bool isRunning(String habitId, String date) => _timers[keyOf(habitId, date)]?.ticker?.isActive ?? false;

  bool isFinished(String habitId, String date) => _timers[keyOf(habitId, date)]?.finished ?? false;

  /// 실행 중인 타이머가 하나라도 있으면 true.
  bool get anyRunning => _timers.values.any((t) => t.ticker?.isActive ?? false);

  void start(String habitId, String date, int totalMinutes) {
    if (totalMinutes <= 0) return;
    final key = keyOf(habitId, date);
    final t = _timers.putIfAbsent(key, () => _RunningTimer(totalMinutes * 60));
    if (t.ticker?.isActive ?? false) return;
    if (t.finished || t.secondsLeft <= 0) t.secondsLeft = totalMinutes * 60; // 끝난 타이머는 처음부터
    t.finished = false;
    t.ticker = Timer.periodic(const Duration(seconds: 1), (timer) async {
      t.secondsLeft -= 1;
      if (t.secondsLeft <= 0) {
        timer.cancel();
        t.secondsLeft = 0;
        t.finished = true;
        await _routine.setDone(habitId, date, true);
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void pause(String habitId, String date) {
    _timers[keyOf(habitId, date)]?.ticker?.cancel();
    notifyListeners();
  }

  void reset(String habitId, String date) {
    final t = _timers.remove(keyOf(habitId, date));
    t?.ticker?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.ticker?.cancel();
    }
    super.dispose();
  }
}
