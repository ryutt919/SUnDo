import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/routine_repository.dart';

class _RunningTimer {
  _RunningTimer(this.secondsLeft);
  int secondsLeft;
  Timer? ticker;
  bool finished = false;
  int missingTicks = 0; // 습관이 없는 채로 지나간 초
}

const _missingTicksLimit = 30;

/// 습관별 타이머를 앱이 살아 있는 동안 유지한다.
/// 상세 시트를 닫았다 다시 열어도 남은 시간이 이어지고, 끝나면 그 날의 습관을 완료로 체크한다.
/// 습관이 삭제되면 그 습관의 타이머도 함께 멈춘다.
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
      // 습관이 없는 동안에는 시간을 줄이지 않고 기다린다. 백업 가져오기가 실패했다가 되돌려지는 짧은 순간
      // (습관이 잠깐 사라진다)에 타이머를 잃지 않게 하려는 것이다. 오래(30초 넘게) 없을 때만 정리한다.
      if (_routine.habitById(habitId) == null) {
        t.missingTicks += 1;
        if (t.missingTicks > _missingTicksLimit) {
          timer.cancel();
          _timers.remove(key);
          notifyListeners();
        }
        return;
      }
      t.missingTicks = 0;
      t.secondsLeft -= 1;
      if (t.secondsLeft <= 0) {
        timer.cancel();
        t.secondsLeft = 0;
        t.finished = true;
        try {
          await _routine.setDone(habitId, date, true);
        } on Exception catch (e) {
          // 기록 저장에 실패하면 완료로 보이지 않게 되돌린다
          debugPrint('타이머 완료 기록 저장 실패: $e');
          t.finished = false;
          t.secondsLeft = 1;
        }
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
