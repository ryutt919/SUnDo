import '../../../../data/repositories/backup_repository.dart';
import '../../../../data/repositories/calendar_repository.dart';
import '../../../../data/repositories/routine_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/services/home_widget_service.dart';
import '../../../../data/services/notification_service.dart';
import '../../../../domain/models/habit.dart';
import '../../../../domain/models/journal_models.dart';
import '../../../core/repo_view_model.dart';

class SettingsViewModel extends RepoViewModel {
  SettingsViewModel({
    required SettingsRepository settings,
    required RoutineRepository routine,
    required BackupRepository backup,
    required NotificationService notifications,
    required HomeWidgetService widgets,
    required CalendarRepository calendar,
  })  : _settings = settings,
        _routine = routine,
        _backup = backup,
        _notifications = notifications,
        _widgets = widgets,
        _calendar = calendar,
        super([settings, routine, calendar]) {
    refreshNotificationState();
  }

  final SettingsRepository _settings;
  final RoutineRepository _routine;
  final BackupRepository _backup;
  final NotificationService _notifications;
  final HomeWidgetService _widgets;
  final CalendarRepository _calendar;

  bool notificationsOn = false;

  AppSettings get settings => _settings.settings;
  List<Habit> get archived => _routine.habits.where((h) => h.archived).toList();
  int get modeCount => _routine.modes.length;

  Future<void> refreshNotificationState() async {
    notificationsOn = await _notifications.notificationsEnabled();
    notifyListeners();
  }

  Future<void> setTheme(String t) => _settings.update(settings.copyWith(theme: t));

  Future<void> setDoneToBottom(bool v) => _settings.update(settings.copyWith(doneToBottom: v));

  Future<void> setMorningAlarm(String hhmm) => _settings.update(settings.copyWith(morningAlarm: hhmm));

  Future<void> setEveningAlarm(String hhmm) => _settings.update(settings.copyWith(eveningAlarm: hhmm));

  Future<bool> requestNotifications() async {
    final ok = await _notifications.requestPermission();
    await refreshNotificationState();
    return ok;
  }

  Future<void> sendTestNotification() => _notifications.showTest();

  Future<bool> get canPinWidget => _widgets.supportsPinning;

  Future<void> pinTodayWidget() => _widgets.requestPin(HomeWidgetService.todayProvider);

  Future<void> pinTodoWidget() => _widgets.requestPin(HomeWidgetService.todoProvider);

  Future<void> pinWeekWidget() => _widgets.requestPin(HomeWidgetService.weekProvider);

  Future<void> pinMonthWidget() => _widgets.requestPin(HomeWidgetService.monthProvider);

  // ---- 캘린더 연동 ----
  bool get calendarOn => _calendar.enabled;
  String get calendarName => _calendar.calendarName;
  int get calendarLinked => _calendar.linkedCount;

  /// 권한을 받고 쓸 수 있는 캘린더 목록을 돌려준다. 권한이 없으면 null.
  Future<List<CalendarChoice>?> loadCalendarChoices() async {
    if (!await _calendar.requestPermission()) return null;
    return _calendar.choices();
  }

  Future<void> enableCalendar(CalendarChoice c) => _calendar.enable(c);

  Future<void> disableCalendar() => _calendar.disable();

  Future<void> removeCalendarEvents() => _calendar.removeAllEvents();

  Future<void> exportBackup() => _backup.export();

  Future<bool> importBackup() => _backup.importFromFile();

  Future<void> restore(String id) async {
    final h = _routine.habitById(id);
    if (h != null) await _routine.updateHabit(h.copyWith(archived: false, clearFinished: true));
  }

  Future<void> purge(String id) => _routine.deleteHabit(id);

  Future<void> wipe() => _backup.resetAll();
}
