// 번호 접두사는 프로젝트 파일 규칙을 따른다.
// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_routine/domain/models/journal_models.dart';
import 'package:my_routine/domain/models/habit.dart';
import 'package:my_routine/ui/features/settings/views/settings_screen.dart';
import 'package:my_routine/ui/features/habit_form/views/add_menu_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_routine/data/repositories/backup_repository.dart';
import 'package:my_routine/data/repositories/calendar_repository.dart';
import 'package:my_routine/data/repositories/journal_repository.dart';
import 'package:my_routine/data/repositories/routine_repository.dart';
import 'package:my_routine/data/repositories/settings_repository.dart';
import 'package:my_routine/data/services/home_widget_service.dart';
import 'package:my_routine/data/services/notification_service.dart';
import 'package:my_routine/data/services/storage_service.dart';
import 'package:my_routine/ui/features/habit_form/view_models/todo_editor_view_model.dart';
import 'package:my_routine/ui/features/settings/view_models/settings_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Calendar extends ChangeNotifier implements CalendarRepository {
  bool readOnly = false;
  bool syncing = false;
  CalendarSyncResult? result;
  DateTime? successAt;
  @override
  bool get enabled => true;
  @override
  String get calendarName => '테스트 캘린더';
  @override
  int get linkedCount => 1;
  @override
  bool get pullChanges => true;
  @override
  bool get importNew => false;
  @override
  bool get isSyncing => syncing;
  @override
  CalendarSyncResult? get lastResult => result;
  @override
  DateTime? get lastSuccessAt => successAt;
  @override
  bool isTodoScheduleReadOnly(String id) => readOnly;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings extends ChangeNotifier implements SettingsRepository {
  @override
  AppSettings get settings => const AppSettings();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Routine extends ChangeNotifier implements RoutineRepository {
  @override
  List<Habit> get habits => [];
  @override
  List<RoutineMode> get modes => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Backup implements BackupRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Notifications extends NotificationService {
  @override
  Future<bool> notificationsEnabled() async => false;
}

void main() {
  test('동기화 결과 다섯 가지를 실제 결과에 맞게 안내한다', () async {
    final vm = SettingsViewModel(
      settings: _Settings(),
      routine: _Routine(),
      backup: _Backup(),
      notifications: _Notifications(),
      widgets: HomeWidgetService(),
      calendar: _Calendar(),
    );
    await Future<void>.delayed(Duration.zero);
    final messages = <CalendarSyncStatus, String>{
      CalendarSyncStatus.success: '3개 반영했어요',
      CalendarSyncStatus.partialFailure: '3개 반영, 2개 실패했어요. 다시 동기화해 주세요',
      CalendarSyncStatus.permissionDenied: '기기 설정에서 캘린더 권한을 허용해 주세요',
      CalendarSyncStatus.disabled: '캘린더 연동이 꺼져 있어요',
      CalendarSyncStatus.failure: '캘린더를 맞추지 못했어요. 다시 시도해 주세요',
    };
    for (final entry in messages.entries) {
      final result = CalendarSyncResult(
        status: entry.key,
        processedCount: 3,
        failedCount: 2,
        completedAt: DateTime(2026, 10, 20),
      );
      expect(vm.calendarSyncMessage(result), entry.value);
    }
    final conflict = CalendarSyncResult(
      status: CalendarSyncStatus.failure,
      processedCount: 0,
      failedCount: 1,
      completedAt: DateTime(2026, 10, 20),
      detail: '투두와 캘린더 일정의 날짜와 시간을 확인하고 같은 값으로 맞춰 주세요',
    );
    expect(vm.calendarSyncMessage(conflict), contains(conflict.detail!));
    vm.dispose();
  });

  testWidgets('동기화 중에는 재실행을 막고 마지막 성공과 최근 실패를 표시한다', (tester) async {
    final calendar = _Calendar()
      ..syncing = true
      ..successAt = DateTime(2026, 10, 19, 12, 30)
      ..result = CalendarSyncResult(
        status: CalendarSyncStatus.permissionDenied,
        processedCount: 0,
        failedCount: 0,
        completedAt: DateTime(2026, 10, 20, 13),
      );
    final vm = SettingsViewModel(
      settings: _Settings(),
      routine: _Routine(),
      backup: _Backup(),
      notifications: _Notifications(),
      widgets: HomeWidgetService(),
      calendar: calendar,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: vm,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.scrollUntilVisible(find.text('동기화 중'), 300);
    final tile = tester.widget<ListTile>(
      find.ancestor(of: find.text('동기화 중'), matching: find.byType(ListTile)),
    );
    expect(tile.onTap, isNull);
    expect(find.textContaining('마지막 성공: 2026-10-19 12:30'), findsOneWidget);
    expect(
      find.textContaining('최근 실패 (2026-10-20 13:00): 기기 설정에서 캘린더 권한'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });

  testWidgets('읽기 전용 일정은 날짜와 시간 버튼을 비활성화하고 이유를 표시한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final journal = JournalRepository(await StorageService.create());
    await journal.load();
    final todo = await journal.addTodo('읽기 전용 회의', '2026-10-20', time: '09:00');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: journal),
          ChangeNotifierProvider<CalendarRepository>.value(
            value: _Calendar()..readOnly = true,
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showTodoDialog(context, todo.date, existing: todo),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('읽기 전용 캘린더 일정이에요'), findsOneWidget);
    for (final label in ['2026-10-20', '09:00']) {
      final button = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(button.onPressed, isNull);
    }
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close))
          .onPressed,
      isNull,
    );
  });

  test('읽기 전용 외부 일정의 날짜와 시간을 변경할 수 없다', () async {
    SharedPreferences.setMockInitialValues({});
    final journal = JournalRepository(await StorageService.create());
    await journal.load();
    final todo = await journal.addTodo('외부 일정', '2026-10-20', time: '09:00');
    final calendar = _Calendar()..readOnly = true;
    final vm = TodoEditorViewModel(
      journal,
      defaultDate: todo.date,
      existing: todo,
      calendar: calendar,
    );
    expect(vm.scheduleReadOnly, isTrue);
    var changes = 0;
    vm.addListener(() => changes++);
    calendar.notifyListeners();
    expect(changes, 1, reason: '캘린더 권한 정보가 바뀌면 편집 화면도 갱신한다');
    vm.setDate('2026-10-21');
    vm.clearTime();
    expect((vm.date, vm.time), ('2026-10-20', '09:00'));
    vm.dispose();
  });

  test('쓰기 가능한 일정의 날짜와 시간은 수정할 수 있다', () async {
    SharedPreferences.setMockInitialValues({});
    final journal = JournalRepository(await StorageService.create());
    await journal.load();
    final todo = await journal.addTodo('외부 일정', '2026-10-20', time: '09:00');
    final vm = TodoEditorViewModel(
      journal,
      defaultDate: todo.date,
      existing: todo,
      calendar: _Calendar(),
    );
    vm.setDate('2026-10-21');
    vm.setTime('11:00');
    expect(await vm.save(), isTrue);
    expect(
      (journal.todos.single.date, journal.todos.single.time),
      ('2026-10-21', '11:00'),
    );
    vm.dispose();
  });

  test('편집 중 삭제된 투두를 되살리지 않고 삭제 상태를 안내한다', () async {
    SharedPreferences.setMockInitialValues({});
    final journal = JournalRepository(await StorageService.create());
    await journal.load();
    final todo = await journal.addTodo('회의', '2026-10-20');
    final vm = TodoEditorViewModel(
      journal,
      defaultDate: todo.date,
      existing: todo,
    )..text = '수정';
    await journal.deleteTodo(todo.id);
    expect(await vm.save(), isFalse);
    expect(vm.saveError, '이 투두는 이미 삭제되었어요');
    expect(journal.todos, isEmpty);
    vm.dispose();
  });

  test('편집하지 않은 필드는 편집 창이 열린 뒤 변경된 최신 값을 보존한다', () async {
    SharedPreferences.setMockInitialValues({});
    final journal = JournalRepository(await StorageService.create());
    await journal.load();
    final todo = await journal.addTodo('회의', '2026-10-20', time: '09:00');
    final vm = TodoEditorViewModel(
      journal,
      defaultDate: todo.date,
      existing: todo,
    );
    await journal.updateTodo(todo.copyWith(done: true, time: '10:00'));
    vm.text = '수정한 회의';
    expect(await vm.save(), isTrue);
    expect(
      (
        journal.todos.single.text,
        journal.todos.single.done,
        journal.todos.single.time,
      ),
      ('수정한 회의', true, '10:00'),
    );
    vm.dispose();
  });
}
