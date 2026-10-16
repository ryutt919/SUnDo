import '../data/repositories/backup_repository.dart';
import '../data/repositories/journal_repository.dart';
import '../data/repositories/routine_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/template_repository.dart';
import '../data/services/backup_service.dart';
import '../data/services/home_widget_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/photo_service.dart';
import '../data/services/storage_service.dart';
import '../domain/use_cases/alarm_plan_use_case.dart';
import '../domain/use_cases/routine_analyzer.dart';
import '../domain/use_cases/stats_use_case.dart';
import '../domain/use_cases/widget_snapshot_use_case.dart';
import '../ui/core/habit_timer_manager.dart';

/// 앱 전체에서 쓰는 서비스, 저장소, 유스케이스를 한 곳에서 만든다.
class AppDependencies {
  AppDependencies._({
    required this.storage,
    required this.routine,
    required this.journal,
    required this.settings,
    required this.templates,
    required this.backup,
    required this.analyzer,
    required this.stats,
    required this.widgetSnapshot,
    required this.alarmPlan,
    required this.notifications,
    required this.widgets,
    required this.photos,
    required this.timers,
  });

  final StorageService storage;
  final RoutineRepository routine;
  final JournalRepository journal;
  final SettingsRepository settings;
  final TemplateRepository templates;
  final BackupRepository backup;
  final RoutineAnalyzer analyzer;
  final StatsUseCase stats;
  final WidgetSnapshotUseCase widgetSnapshot;
  final AlarmPlanUseCase alarmPlan;
  final NotificationService notifications;
  final HomeWidgetService widgets;
  final PhotoService photos;
  final HabitTimerManager timers;

  static Future<AppDependencies> create() async {
    final storage = await StorageService.create();
    final routine = RoutineRepository(storage);
    final journal = JournalRepository(storage);
    final settings = SettingsRepository(storage);
    final analyzer = RoutineAnalyzer(routine);
    final notifications = NotificationService();
    final photos = PhotoService();

    await Future.wait([routine.load(), journal.load(), settings.load(), notifications.init()]);

    return AppDependencies._(
      storage: storage,
      routine: routine,
      journal: journal,
      settings: settings,
      templates: TemplateRepository(),
      backup: BackupRepository(BackupService(), photos, routine, journal, settings),
      analyzer: analyzer,
      stats: StatsUseCase(routine, analyzer),
      widgetSnapshot: WidgetSnapshotUseCase(routine, analyzer, journal: journal),
      alarmPlan: AlarmPlanUseCase(routine, analyzer),
      notifications: notifications,
      widgets: HomeWidgetService(),
      photos: photos,
      timers: HabitTimerManager(routine),
    );
  }

  /// 위젯(다른 isolate)이 저장소를 바꿨을 수 있으니 디스크에서 다시 읽는다.
  Future<void> reloadFromDisk() async {
    await storage.reload();
    await Future.wait([routine.load(), journal.load(), settings.load()]);
  }
}
