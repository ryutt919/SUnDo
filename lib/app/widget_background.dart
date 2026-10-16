import 'package:flutter/widgets.dart';

import '../data/repositories/routine_repository.dart';
import '../data/services/home_widget_service.dart';
import '../data/services/storage_service.dart';
import '../domain/models/date_key.dart';
import '../domain/use_cases/routine_analyzer.dart';
import '../domain/use_cases/widget_snapshot_use_case.dart';

/// 홈 화면 위젯이 앱을 열지 않고 보내는 요청을 백그라운드에서 처리한다.
///  - `myroutine://toggle?id=<습관 ID>`: 오늘 그 습관의 체크를 바꾼다.
///  - `myroutine://refresh`: 날짜가 바뀌었을 때 위젯 데이터를 새로 만든다.
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (uri == null) return;

  final storage = await StorageService.create();
  final routine = RoutineRepository(storage);
  await routine.load();

  switch (uri.host) {
    case 'toggle':
      final id = uri.queryParameters['id'];
      if (id == null || id.isEmpty) return;
      await routine.toggle(id, todayKey());
    case 'refresh':
      break;
    default:
      debugPrint('알 수 없는 위젯 요청: $uri');
      return;
  }

  final snapshot = WidgetSnapshotUseCase(routine, RoutineAnalyzer(routine)).build();
  await HomeWidgetService().push(snapshot);
}
