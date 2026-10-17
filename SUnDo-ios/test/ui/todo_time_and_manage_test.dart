import 'package:flutter_test/flutter_test.dart';
import 'package:my_routine/app/widget_link.dart';
import 'package:my_routine/data/repositories/journal_repository.dart';
import 'package:my_routine/data/services/storage_service.dart';
import 'package:my_routine/data/repositories/routine_repository.dart';
import 'package:my_routine/domain/models/journal_models.dart';
import 'package:my_routine/domain/models/repeat_rule.dart';
import 'package:my_routine/domain/use_cases/routine_analyzer.dart';
import 'package:my_routine/domain/use_cases/widget_snapshot_use_case.dart';
import 'package:my_routine/ui/features/habit_form/view_models/todo_editor_view_model.dart';
import 'package:my_routine/ui/features/manage/view_models/bulk_delete_view_model.dart';
import 'package:my_routine/ui/features/todos/view_models/todos_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

const _today = '2026-10-14';

Future<JournalRepository> _journal() async {
  SharedPreferences.setMockInitialValues({});
  final store = await StorageService.create();
  final j = JournalRepository(store);
  await j.load();
  return j;
}

void main() {
  group('투두의 날짜와 시간', () {
    test('시간을 안 넣으면 종일이고, 넣으면 저장 후 다시 읽어도 남는다', () async {
      final j = await _journal();
      final all = await j.addTodo('종일', _today);
      final timed = await j.addTodo('약속', _today, time: '14:30');
      expect(all.hasTime, isFalse);
      expect(Todo.fromJson(all.toJson()).time, '');
      expect(all.toJson().containsKey('time'), isFalse, reason: '종일 투두는 예전 백업과 같은 모양');
      expect(Todo.fromJson(timed.toJson()).time, '14:30');
      expect(Todo.fromJson({'id': 'x', 'date': _today}).time, '', reason: '시간 필드가 없는 예전 데이터');
    });

    test('같은 날에는 시간이 있는 투두를 시간 순으로 앞에, 종일은 뒤에 둔다', () {
      Todo t(String id, String date, [String time = '']) => Todo(id: id, text: id, date: date, time: time);
      final sorted = sortTodos([t('종일1', _today), t('늦게', _today, '18:00'), t('다음날', '2026-10-15', '08:00'), t('일찍', _today, '07:30'), t('종일2', _today)]);
      expect(sorted.map((e) => e.id), ['일찍', '늦게', '종일1', '종일2', '다음날']);
    });

    test('편집 화면은 시간을 넣고 지울 수 있고 날짜 선택은 유지된다', () async {
      final j = await _journal();
      final vm = TodoEditorViewModel(j, defaultDate: _today);
      vm.text = '회의';
      vm.setDate('2026-10-20');
      vm.setTime('09:05');
      expect(await vm.save(), isTrue);
      var saved = j.todos.single;
      expect((saved.date, saved.time), ('2026-10-20', '09:05'));

      final edit = TodoEditorViewModel(j, defaultDate: _today, existing: saved);
      expect((edit.date, edit.time, edit.isNew), ('2026-10-20', '09:05', false));
      edit.clearTime();
      expect(await edit.save(), isTrue);
      saved = j.todos.single;
      expect(saved.time, '', reason: '시간을 지우면 종일로 돌아간다');
      expect(saved.date, '2026-10-20');
    });

    test('내용이 비면 저장하지 않는다', () async {
      final j = await _journal();
      final vm = TodoEditorViewModel(j, defaultDate: _today)..text = '   ';
      expect(await vm.save(), isFalse);
      expect(j.todos, isEmpty);
    });

    test('날짜만 바꿔 고쳐도 시간은 그대로 남는다', () async {
      final j = await _journal();
      final t = await j.addTodo('약속', _today, time: '10:00');
      await j.updateTodo(t.copyWith(date: '2026-10-16'));
      expect(j.todos.single.time, '10:00');
    });
  });

  group('일괄 삭제', () {
    test('투두 여러 개를 한 번에 지운다', () async {
      final j = await _journal();
      final a = await j.addTodo('a', _today);
      final b = await j.addTodo('b', _today);
      await j.addTodo('c', _today);
      await TodosViewModel(j).deleteMany({a.id, b.id});
      expect(j.todos.map((t) => t.text), ['c']);
    });

    test('앱에서 일괄 삭제해도 위젯(다른 인스턴스)이 방금 바꾼 투두는 남고, 지운 투두는 되살아나지 않는다', () async {
      final app = await _journal();
      final a = await app.addTodo('a', _today);
      final b = await app.addTodo('b', _today);
      final c = await app.addTodo('c', _today);
      final widget = JournalRepository(await StorageService.create());
      await widget.load();
      await widget.updateTodo(widget.todos.firstWhere((t) => t.id == b.id).copyWith(done: true)); // 위젯이 체크
      await app.deleteTodos({a.id}); // 앱은 위젯의 변경을 아직 모르는 상태에서 삭제
      final check = JournalRepository(await StorageService.create());
      await check.load();
      expect(check.todos.map((t) => t.text).toSet(), {'b', 'c'});
      expect(check.todos.firstWhere((t) => t.id == b.id).done, isTrue, reason: '위젯의 체크가 유실되면 안 된다');

      // 반대로 앱에서 지운 투두를 위젯의 오래된 목록이 되살리지 않는다
      await app.deleteTodos({c.id});
      await widget.updateTodo(widget.todos.firstWhere((t) => t.id == b.id).copyWith(done: false));
      final check2 = JournalRepository(await StorageService.create());
      await check2.load();
      expect(check2.todos.map((t) => t.text), ['b'], reason: '삭제한 c가 되살아나면 안 된다');
    });

    test('루틴 일괄 삭제는 다른 인스턴스(위젯)가 먼저 한 다른 루틴의 체크를 지우지 않는다', () async {
      final app = await emptyRoutine();
      await app.addHabit(habit('a'));
      await app.addHabit(habit('b'));
      final widget = RoutineRepository(await StorageService.create());
      await widget.load();
      await widget.toggle('b', _today);
      await app.deleteHabits({'a'});
      final check = RoutineRepository(await StorageService.create());
      await check.load();
      expect(check.habits.map((h) => h.id), ['b']);
      expect(check.isDone('b', _today), isTrue);
    });

    test('루틴 여러 개와 그 기록을 한 번에 지운다', () async {
      final r = await emptyRoutine();
      await r.addHabit(habit('a'));
      await r.addHabit(habit('b'));
      await r.addHabit(habit('c'));
      await r.setDone('a', _today, true);
      await r.setDone('c', _today, true);
      await r.deleteHabits({'a', 'b'});
      expect(r.habits.map((h) => h.id), ['c']);
      expect(r.isDone('a', _today), isFalse);
      expect(r.isDone('c', _today), isTrue);
    });

    test('관리 화면 상태: 전체 선택, 개별 선택, 삭제 후 선택이 비워진다', () async {
      var items = [for (final i in ['a', 'b', 'c']) ManageItem(id: i, title: i)];
      Set<String>? deleted;
      final vm = BulkDeleteViewModel(
        items: () => items,
        onDelete: (ids) async {
          deleted = ids;
          items = items.where((i) => !ids.contains(i.id)).toList();
        },
      );
      expect(vm.selectedCount, 0);
      vm.toggle('a');
      expect(vm.isSelected('a'), isTrue);
      vm.toggleAll();
      expect(vm.allSelected, isTrue);
      vm.toggleAll();
      expect(vm.selectedCount, 0);
      vm.toggle('a');
      vm.toggle('c');
      expect(await vm.deleteSelected(), 2);
      expect(deleted, {'a', 'c'});
      expect(vm.selectedCount, 0);
      expect(vm.items.map((i) => i.id), ['b']);
      expect(await vm.deleteSelected(), 0, reason: '고른 것이 없으면 아무것도 하지 않는다');
    });

    test('다른 곳에서 사라진 항목은 선택에서도 빠진다', () {
      var items = [const ManageItem(id: 'a', title: 'a'), const ManageItem(id: 'b', title: 'b')];
      final vm = BulkDeleteViewModel(items: () => items, onDelete: (_) async {});
      vm.toggle('a');
      items = [items[1]];
      expect(vm.items.length, 1);
      expect(vm.selectedCount, 0);
    });
  });

  group('위젯 데이터와 "+" 링크', () {
    test('루틴과 투두를 개수 제한 없이 모두 담고, 투두에는 시간이 붙는다', () async {
      final routine = await emptyRoutine();
      final store = await StorageService.create();
      final journal = JournalRepository(store);
      await journal.load();
      for (var i = 0; i < 12; i++) {
        await routine.addHabit(habit('h$i', name: '루틴$i'));
        await journal.addTodo('투두$i', _today, time: i == 0 ? '09:00' : '');
      }
      await journal.addTodo('밀린 일', '2026-10-13', time: '20:15');
      final snap = WidgetSnapshotUseCase(routine, RoutineAnalyzer(routine, today: () => _today), journal: journal).build();
      expect((snap['rows'] as List).length, 12);
      expect((snap['todos'] as List).length, 13);
      expect(snap.containsKey('more'), isFalse);
      expect(snap.containsKey('todoMore'), isFalse);
      final times = (snap['todos'] as List).cast<Map>().map((t) => t['time']).toList();
      expect(times.first, '10-13 이월 20:15');
      expect(times[1], '오늘 09:00', reason: '오늘 투두 중 시간이 있는 것이 먼저');
      expect(times.last, '오늘');
    });

    test('위젯 "+" 주소를 투두와 루틴 추가로 해석한다', () {
      expect(parseWidgetLink(Uri.parse('myroutine://add?kind=todo')), WidgetAddTarget.todo);
      expect(parseWidgetLink(Uri.parse('myroutine://add?kind=routine')), WidgetAddTarget.routine);
      expect(parseWidgetLink(Uri.parse('myroutine://add?kind=todo&homeWidget')), WidgetAddTarget.todo, reason: 'iOS 위젯 링크의 homeWidget 표시');
      expect(parseWidgetLink(Uri.parse('myroutine://add')), isNull);
      expect(parseWidgetLink(Uri.parse('myroutine://open')), isNull);
      expect(parseWidgetLink(Uri.parse('https://add?kind=todo')), isNull);
      expect(parseWidgetLink(null), isNull);
    });

    test('주간 루틴도 일괄 삭제 대상으로 구분된다', () async {
      final r = await emptyRoutine();
      await r.addHabit(habit('d'));
      await r.addHabit(habit('w', repeat: const RepeatRule(type: RepeatType.weekly, times: 3)));
      expect(r.habits.where((h) => h.repeat.type == RepeatType.weekly).map((h) => h.id), ['w']);
    });
  });
}
