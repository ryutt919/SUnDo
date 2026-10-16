import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_dependencies.dart';

/// 데이터가 바뀔 때마다 홈 화면 위젯과 알람 예약을 맞춰 준다.
class AppSync {
  AppSync(this._deps);

  final AppDependencies _deps;
  Timer? _debounce;

  void start() {
    _deps.routine.addListener(_schedule);
    _deps.journal.addListener(_schedule);
    _deps.settings.addListener(_schedule);
    syncNow();
  }

  void dispose() {
    _debounce?.cancel();
    _deps.routine.removeListener(_schedule);
    _deps.journal.removeListener(_schedule);
    _deps.settings.removeListener(_schedule);
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), syncNow);
  }

  Future<void> syncNow() async {
    try {
      await _deps.widgets.push(_deps.widgetSnapshot.build());
    } on Exception catch (e) {
      debugPrint('위젯 갱신 실패: $e');
    }
    try {
      final s = _deps.settings.settings;
      await _deps.notifications.replaceAll(
        _deps.alarmPlan.build(morning: s.morningAlarm, evening: s.eveningAlarm),
      );
    } on Exception catch (e) {
      debugPrint('알람 예약 실패: $e');
    }
  }
}
