import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_dependencies.dart';

/// 데이터가 바뀔 때마다 홈 화면 위젯과 알람 예약을 맞춰 준다.
class AppSync {
  AppSync(this._deps);

  final AppDependencies _deps;
  Timer? _debounce;
  Future<void> _chain = Future.value();

  void start() {
    _deps.routine.addListener(_schedule);
    _deps.journal.addListener(_schedule);
    _deps.settings.addListener(_schedule);
    _deps.calendar.addListener(_scheduleOnCalendarSettings);
    syncNow();
  }

  void dispose() {
    _debounce?.cancel();
    _deps.routine.removeListener(_schedule);
    _deps.journal.removeListener(_schedule);
    _deps.settings.removeListener(_schedule);
    _deps.calendar.removeListener(_scheduleOnCalendarSettings);
  }

  // 동기화가 끝날 때마다 캘린더 저장소도 알림을 보내므로, 연동 설정이 바뀐 경우에만 다시 맞춘다.
  bool _lastCalendarOn = false;
  String _lastCalendarId = '';

  void _scheduleOnCalendarSettings() {
    final cal = _deps.calendar;
    if (cal.enabled == _lastCalendarOn && cal.calendarId == _lastCalendarId) return;
    _lastCalendarOn = cal.enabled;
    _lastCalendarId = cal.calendarId;
    _schedule();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), syncNow);
  }

  /// 동기화는 한 번에 하나씩만 실행한다. 예약을 지우고 다시 만드는 작업이 겹치면
  /// 이미 지운 알람이 되살아날 수 있기 때문이다.
  Future<void> syncNow() {
    _chain = _chain.then((_) => _run());
    return _chain;
  }

  Future<void> _run() async {
    try {
      await _deps.widgets.push(_deps.widgetSnapshot.build());
    } on Exception catch (e) {
      debugPrint('위젯 갱신 실패: $e');
    }
    try {
      await _deps.calendar.sync(_deps.journal.todos);
    } on Exception catch (e) {
      debugPrint('캘린더 동기화 실패: $e');
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
