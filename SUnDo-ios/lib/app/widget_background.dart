import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/repositories/journal_repository.dart';
import '../data/repositories/routine_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/services/home_widget_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/storage_service.dart';
import '../domain/models/date_key.dart';
import '../domain/use_cases/alarm_plan_use_case.dart';
import '../domain/use_cases/routine_analyzer.dart';
import '../domain/use_cases/widget_snapshot_use_case.dart';

/// 홈 화면 위젯이 앱을 열지 않고 보내는 요청을 백그라운드에서 처리한다.
///  - `myroutine://toggle?id=<루틴 ID>`: 오늘 그 루틴의 체크를 바꾼다.
///  - `myroutine://toggletodo?id=<투두 ID>`: 그 투두의 완료 상태를 바꾼다.
///  - `myroutine://refresh`: 날짜나 시간대가 바뀌었을 때 위젯 데이터와 알람을 새로 만든다.
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (uri == null) return;
  await HomeWidgetService.configure();

  final storage = await StorageService.create();
  final routine = RoutineRepository(storage);
  final journal = JournalRepository(storage);
  await Future.wait([routine.load(), journal.load()]);

  switch (uri.host) {
    case 'toggletodo': // URI 호스트는 소문자로 정규화되므로 소문자로 쓴다
      final id = uri.queryParameters['id'];
      if (id == null || id.isEmpty) return;
      final todo = journal.todos.where((t) => t.id == id).firstOrNull;
      if (todo != null) {
        try {
          await journal.updateTodo(todo.copyWith(done: !todo.done));
        } on StorageWriteException catch (e) {
          debugPrint('위젯 투두 저장 실패: $e');
        }
      }
    case 'toggle':
      final id = uri.queryParameters['id'];
      if (id == null || id.isEmpty) return;
      try {
        await routine.toggle(id, todayKey());
      } on StorageWriteException catch (e) {
        // 저장에 실패하면 체크가 바뀌지 않은 상태 그대로 위젯을 다시 그려, 화면과 저장 내용이 어긋나지 않게 한다
        debugPrint('위젯 체크 저장 실패: $e');
      }
    case 'refresh':
      break;
    default:
      debugPrint('알 수 없는 위젯 요청: $uri');
      return;
  }

  final analyzer = RoutineAnalyzer(routine);
  await HomeWidgetService().push(WidgetSnapshotUseCase(routine, analyzer, journal: journal).build());

  // 위젯에서 체크한 루틴의 알람을 취소하고, 앱을 오래 열지 않아도 알람 예약이 이어지게 다시 만든다.
  try {
    final settings = SettingsRepository(storage);
    await settings.load();
    final s = settings.settings;
    final notifications = NotificationService();
    await notifications.init();
    await notifications.replaceAll(
      AlarmPlanUseCase(routine, analyzer).build(morning: s.morningAlarm, evening: s.eveningAlarm),
    );
  } on Exception catch (e) {
    debugPrint('위젯 콜백에서 알람 재예약 실패: $e');
  }
}
