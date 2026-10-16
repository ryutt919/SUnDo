import 'dart:convert';

import 'package:home_widget/home_widget.dart';

/// 안드로이드 홈 화면 위젯(네이티브 Kotlin)에 데이터를 넘기고 갱신을 요청한다.
class HomeWidgetService {
  static const _package = 'com.sundo.my_routine';
  static const todayProvider = '$_package.TodayWidgetProvider';
  static const weekProvider = '$_package.WeekWidgetProvider';
  static const monthProvider = '$_package.MonthWidgetProvider';
  static const snapshotKey = 'snapshot';

  Future<void> push(Map<String, dynamic> snapshot) async {
    await HomeWidget.saveWidgetData<String>(snapshotKey, jsonEncode(snapshot));
    await HomeWidget.updateWidget(qualifiedAndroidName: todayProvider);
    await HomeWidget.updateWidget(qualifiedAndroidName: weekProvider);
    await HomeWidget.updateWidget(qualifiedAndroidName: monthProvider);
  }

  Future<bool> get supportsPinning async => (await HomeWidget.isRequestPinWidgetSupported()) ?? false;

  Future<void> requestPin(String qualifiedName) => HomeWidget.requestPinWidget(qualifiedAndroidName: qualifiedName);
}
