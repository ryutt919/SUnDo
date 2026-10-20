// ignore_for_file: file_names

import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_routine/data/repositories/calendar_repository.dart';
import 'package:my_routine/data/repositories/journal_repository.dart';
import 'package:my_routine/data/services/calendar_service.dart';
import 'package:my_routine/data/services/storage_service.dart';
import 'package:my_routine/domain/models/date_key.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 실행 전 앱에 캘린더 전체 접근 권한을 부여한다.
/// Android: adb shell pm grant com.sundo.my_routine android.permission.READ_CALENDAR
/// Android: adb shell pm grant com.sundo.my_routine android.permission.WRITE_CALENDAR
/// iOS: xcrun simctl privacy booted grant calendar com.sundo.myRoutine
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('실제 기기 캘린더와 투두의 시각, 종일, 날짜 양방향 동기화', (tester) async {
    await tester.runAsync(() async {
      // 실제 사용자 저장소에는 접근하지 않는다. 캘린더만 네이티브 구현이다.
      SharedPreferences.setMockInitialValues({});
      final store = await StorageService.create();
      final journal = JournalRepository(store);
      final native = DeviceCalendar.instance;
      final service = CalendarService(plugin: native);
      final repo = CalendarRepository(store, service, journal);
      await journal.load();
      await repo.load();
      expect(
        await service.hasPermission(),
        isTrue,
        reason: '권한 대화상자 없이 실행하도록 설치 후 캘린더 권한을 먼저 부여해야 함',
      );

      final name = 'Routining-test-${DateTime.now().microsecondsSinceEpoch}';
      final calendarId = await native.createCalendar(name: name);
      try {
        await repo.setImportCalendars({calendarId});
        await repo.enable(
          CalendarChoice(
            id: calendarId,
            name: name,
            account: '',
            isPrimary: false,
          ),
        );
        final now = DateTime.now();
        final day = DateTime(now.year, now.month, now.day + 2);
        final nextDay = DateTime(day.year, day.month, day.day + 1);

        Future<void> sync() async {
          final result = await repo.sync();
          expect(
            result.status,
            CalendarSyncStatus.success,
            reason: '동기화 실패: ${result.detail}',
          );
          expect(result.failedCount, 0);
        }

        Future<CalendarEvent> onlyEvent() async {
          final events = await service.listBetween(
            calendarIds: [calendarId],
            from: DateTime(day.year, day.month, day.day - 1),
            to: DateTime(day.year, day.month, day.day + 5),
          );
          expect(events, hasLength(1), reason: '같은 투두의 일정이 중복 생성되면 안 됨');
          return events.single;
        }

        void schedule(CalendarEvent event, DateTime date, String time) {
          expect(dateKey(event.day), dateKey(date));
          expect(event.time, time);
          expect(event.allDay, time.isEmpty);
        }

        var todo = await journal.addTodo(
          '네이티브 시간 검증',
          dateKey(day),
          time: '09:30',
        );
        await sync();
        var event = await onlyEvent();
        final eventId = event.id;
        schedule(event, day, '09:30');
        expect(event.end!.difference(event.start!), const Duration(hours: 1));

        // 제목만 수정할 때 기존 시각과 길이가 유지되어야 한다.
        todo = todo.copyWith(text: '수정한 네이티브 시간 검증');
        await journal.updateTodo(todo);
        await sync();
        event = await onlyEvent();
        expect(event.title, todo.text);
        schedule(event, day, '09:30');

        todo = todo.copyWith(time: '14:45');
        await journal.updateTodo(todo);
        await sync();
        event = await onlyEvent();
        schedule(event, day, '14:45');
        expect(event.end!.difference(event.start!), const Duration(hours: 1));

        // 시간을 지우면 종일 일정이 되고 종료일은 다음 날이다.
        todo = todo.copyWith(time: '');
        await journal.updateTodo(todo);
        await sync();
        event = await onlyEvent();
        schedule(event, day, '');
        expect(dateKey(event.end!), dateKey(nextDay));

        // 종일 상태에서 날짜만 이동한 뒤 다시 시간 일정으로 바꾼다.
        todo = todo.copyWith(date: dateKey(nextDay));
        await journal.updateTodo(todo);
        await sync();
        schedule(await onlyEvent(), nextDay, '');
        todo = todo.copyWith(time: '08:15');
        await journal.updateTodo(todo);
        await sync();
        schedule(await onlyEvent(), nextDay, '08:15');

        // CalendarService의 nullable 시각 계약: 날짜만 넘기면 시각 유지.
        expect(await service.update(eventId: eventId, day: day), isTrue);
        await sync();
        todo = journal.todos.single;
        expect(todo.date, dateKey(day));
        expect(todo.time, '08:15');

        // 외부 캘린더 앱의 편집을 네이티브 플러그인으로 재현한다.
        final externalStart = DateTime(
          nextDay.year,
          nextDay.month,
          nextDay.day,
          16,
          20,
        );
        await native.updateEvent(
          instanceId: eventId,
          title: '외부에서 수정한 일정',
          startDate: externalStart,
          endDate: externalStart.add(const Duration(minutes: 95)),
          isAllDay: false,
        );
        await sync();
        todo = journal.todos.single;
        expect(todo.text, '외부에서 수정한 일정');
        expect(todo.date, dateKey(nextDay));
        expect(todo.time, '16:20');

        // 외부 일정의 길이는 투두 제목 수정으로 바뀌지 않는다.
        await journal.updateTodo(todo.copyWith(text: '길이를 유지하는 제목 변경'));
        await sync();
        event = await onlyEvent();
        expect(
          event.end!.difference(event.start!),
          const Duration(minutes: 95),
        );

        await native.updateEvent(
          instanceId: eventId,
          startDate: nextDay,
          endDate: DateTime(nextDay.year, nextDay.month, nextDay.day + 1),
          isAllDay: true,
        );
        await sync();
        expect(journal.todos.single.time, '');
        expect(journal.todos.single.date, dateKey(nextDay));
        schedule(await onlyEvent(), nextDay, '');

        await sync();
        await sync();
        expect(journal.todos, hasLength(1));
        expect((await onlyEvent()).id, eventId);
        expect(repo.linkedCount, 1);
      } finally {
        // 테스트가 실패해도 이번 실행에서 만든 캘린더 하나만 삭제한다.
        await native.deleteCalendar(calendarId);
        expect(
          (await native.listCalendars()).any((c) => c.id == calendarId),
          isFalse,
          reason: '테스트용 캘린더 삭제 확인',
        );
        repo.dispose();
        journal.dispose();
      }
    });
  }, timeout: const Timeout(Duration(minutes: 3)));
}
