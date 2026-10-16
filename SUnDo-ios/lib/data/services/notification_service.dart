import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/use_cases/alarm_plan_use_case.dart';

/// 루틴 알람을 로컬 알림으로 예약한다(Android, iOS).
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'habit_alarms',
      '루틴 알람',
      channelDescription: '루틴을 할 시간에 알려 줘요',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_notify',
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentBanner: true, presentSound: true),
  );

  Future<void> init() async {
    tz_data.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notify'),
        // 권한은 설정 화면의 버튼에서 요청한다(시작하자마자 묻지 않는다)
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  Future<bool> notificationsEnabled() async {
    if (_isIos) return (await _ios?.checkPermissions())?.isEnabled ?? false;
    return (await _android?.areNotificationsEnabled()) ?? false;
  }

  /// 알림 권한을 요청한다(Android 13 이상과 iOS).
  Future<bool> requestPermission() async {
    if (_isIos) return (await _ios?.requestPermissions(alert: true, badge: false, sound: true)) ?? false;
    final granted = await _android?.requestNotificationsPermission();
    await _android?.requestExactAlarmsPermission();
    return granted ?? false;
  }

  Future<void> showTest() => _plugin.show(
        id: 1,
        title: '알림 테스트',
        body: '이렇게 알려 드려요',
        notificationDetails: _details,
      );

  /// 예약된 알림을 모두 지우고 새 계획으로 다시 예약한다.
  Future<void> replaceAll(List<AlarmSpec> specs) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    if (!await notificationsEnabled()) return;
    final exact = _isIos ? false : ((await _android?.canScheduleExactNotifications()) ?? false);
    for (final s in specs) {
      try {
        await _plugin.zonedSchedule(
          id: s.id,
          title: s.title,
          body: s.body,
          scheduledDate: tz.TZDateTime.from(s.at, tz.local),
          notificationDetails: _details,
          androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } on Exception catch (e) {
        debugPrint('알람 예약 실패 (${s.title} ${s.at}): $e');
      }
    }
  }
}
