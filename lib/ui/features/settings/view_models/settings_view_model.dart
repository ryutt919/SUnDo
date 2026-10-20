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
  }) : _settings = settings,
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

  Future<void> setTheme(String t) =>
      _settings.update(settings.copyWith(theme: t));

  Future<void> setDoneToBottom(bool v) =>
      _settings.update(settings.copyWith(doneToBottom: v));

  Future<void> setMorningAlarm(String hhmm) =>
      _settings.update(settings.copyWith(morningAlarm: hhmm));

  Future<void> setEveningAlarm(String hhmm) =>
      _settings.update(settings.copyWith(eveningAlarm: hhmm));

  Future<bool> requestNotifications() async {
    final ok = await _notifications.requestPermission();
    await refreshNotificationState();
    return ok;
  }

  Future<void> sendTestNotification() => _notifications.showTest();

  Future<bool> get canPinWidget => _widgets.supportsPinning;

  Future<void> pinTodayWidget() =>
      _widgets.requestPin(HomeWidgetService.todayProvider);

  Future<void> pinTodoWidget() =>
      _widgets.requestPin(HomeWidgetService.todoProvider);

  Future<void> pinWeekWidget() =>
      _widgets.requestPin(HomeWidgetService.weekProvider);

  Future<void> pinMonthWidget() =>
      _widgets.requestPin(HomeWidgetService.monthProvider);

  // ---- 캘린더 연동 ----
  bool get calendarOn => _calendar.enabled;
  String get calendarName => _calendar.calendarName;
  int get calendarLinked => _calendar.linkedCount;
  bool get calendarPull => _calendar.pullChanges;
  bool get calendarImport => _calendar.importNew;

  Future<void> setCalendarPull(bool v) async {
    await _calendar.setPullChanges(v);
    await _calendar.sync();
  }

  Future<void> setCalendarImport(bool v) async {
    await _calendar.setImportNew(v);
    await _calendar.sync();
  }

  /// 직접 고른 가져올 캘린더(null이면 기본값: 쓰기 가능한 모든 캘린더).
  Set<String>? get calendarImportIds => _calendar.importCalendarIds;

  Future<List<CalendarChoice>> loadImportChoices() => _calendar.importChoices();

  Future<void> setCalendarImportIds(Set<String>? ids) async {
    await _calendar.setImportCalendars(ids);
    await _calendar.sync();
  }

  bool get calendarSyncing => _calendar.isSyncing;
  DateTime? get calendarLastSuccessAt => _calendar.lastSuccessAt;
  CalendarSyncResult? get calendarLastResult => _calendar.lastResult;

  Future<CalendarSyncResult> syncCalendarNow() => _calendar.sync();

  String calendarSyncMessage(CalendarSyncResult result) {
    final message = switch (result.status) {
      CalendarSyncStatus.success =>
        result.processedCount == 0
            ? '캘린더와 맞췄어요. 변경 사항이 없어요'
            : '${result.processedCount}개 반영했어요',
      CalendarSyncStatus.partialFailure =>
        '${result.processedCount}개 반영, ${result.failedCount}개 실패했어요. 다시 동기화해 주세요',
      CalendarSyncStatus.permissionDenied => '기기 설정에서 캘린더 권한을 허용해 주세요',
      CalendarSyncStatus.disabled => '캘린더 연동이 꺼져 있어요',
      CalendarSyncStatus.failure => '캘린더를 맞추지 못했어요. 다시 시도해 주세요',
    };
    final detail = result.detail;
    if (detail != null &&
        detail.isNotEmpty &&
        (result.status == CalendarSyncStatus.failure ||
            result.status == CalendarSyncStatus.partialFailure)) {
      return '$message\n$detail';
    }
    return message;
  }

  String get calendarSyncDescription {
    final lastSuccess = calendarLastSuccessAt;
    final last = calendarLastResult;
    final lines = <String>[
      '앱을 열 때와 투두를 바꿀 때 자동으로 맞춰요',
      if (lastSuccess == null)
        '아직 성공한 동기화가 없어요'
      else
        '마지막 성공: ${_formatSyncTime(lastSuccess)}',
      if (last != null &&
          last.status != CalendarSyncStatus.success &&
          last.status != CalendarSyncStatus.disabled)
        '최근 실패 (${_formatSyncTime(last.completedAt)}): ${calendarSyncMessage(last)}',
    ];
    return lines.join('\n');
  }

  static String _formatSyncTime(DateTime value) {
    final t = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

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
    if (h != null) {
      await _routine.updateHabit(
        h.copyWith(archived: false, clearFinished: true),
      );
    }
  }

  Future<void> purge(String id) => _routine.deleteHabit(id);

  Future<void> wipe() => _backup.resetAll();
}
