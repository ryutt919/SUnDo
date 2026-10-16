import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// 홈 화면 위젯에 데이터를 넘기고 갱신을 요청한다.
/// Android는 네이티브 Kotlin 위젯, iOS는 WidgetKit 확장이 같은 `snapshot` JSON을 읽는다.
class HomeWidgetService {
  static const _package = 'com.sundo.my_routine';
  static const todayProvider = '$_package.TodayWidgetProvider';
  static const todoProvider = '$_package.TodoWidgetProvider';
  static const weekProvider = '$_package.WeekWidgetProvider';
  static const monthProvider = '$_package.MonthWidgetProvider';
  static const snapshotKey = 'snapshot';

  /// iOS 앱과 위젯 확장이 데이터를 나눠 쓰는 App Group. Xcode의 Signing & Capabilities에서 같은 값을 추가해야 한다.
  static const appGroupId = 'group.com.sundo.myRoutine';

  /// WidgetKit 위젯의 kind 이름(Swift의 `kind`와 같아야 한다).
  static const iosWidgetKinds = ['RoutiningToday', 'RoutiningTodo'];

  static bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  /// 앱이 시작할 때 한 번 호출한다. iOS에서만 App Group을 지정한다.
  static Future<void> configure() async {
    if (_isIos) await HomeWidget.setAppGroupId(appGroupId);
  }

  Future<void> push(Map<String, dynamic> snapshot) async {
    await HomeWidget.saveWidgetData<String>(snapshotKey, jsonEncode(snapshot));
    if (_isIos) {
      for (final kind in iosWidgetKinds) {
        await HomeWidget.updateWidget(iOSName: kind);
      }
      return;
    }
    await HomeWidget.updateWidget(qualifiedAndroidName: todayProvider);
    await HomeWidget.updateWidget(qualifiedAndroidName: todoProvider);
    await HomeWidget.updateWidget(qualifiedAndroidName: weekProvider);
    await HomeWidget.updateWidget(qualifiedAndroidName: monthProvider);
  }

  /// iOS는 앱에서 위젯을 직접 추가할 수 없다(홈 화면 길게 누르기로 추가).
  Future<bool> get supportsPinning async => _isIos ? false : (await HomeWidget.isRequestPinWidgetSupported()) ?? false;

  Future<void> requestPin(String qualifiedName) => HomeWidget.requestPinWidget(qualifiedAndroidName: qualifiedName);
}
