import 'package:flutter_test/flutter_test.dart';
import 'package:my_routine/data/repositories/journal_repository.dart';
import 'package:my_routine/data/services/storage_service.dart';
import 'package:my_routine/domain/models/date_key.dart';
import 'package:my_routine/ui/features/todos/view_models/todos_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<({TodosViewModel vm, JournalRepository journal})> _setup() async {
  SharedPreferences.setMockInitialValues({});
  final store = await StorageService.create();
  final journal = JournalRepository(store);
  await journal.load();
  return (vm: TodosViewModel(journal), journal: journal);
}

void main() {
  test('빠른 추가는 오늘 할 일로 들어가고 빈 글자는 무시한다', () async {
    final s = await _setup();
    await s.vm.quickAdd('  우유 사기  ');
    await s.vm.quickAdd('   ');
    expect(s.vm.todayOpen.map((t) => t.text), ['우유 사기']);
    expect(s.journal.todos.length, 1);
  });

  test('투두는 지난 미완료, 오늘, 예정, 완료로 나뉜다', () async {
    final s = await _setup();
    final today = todayKey();
    await s.journal.addTodo('어제 것', addDaysKey(today, -1));
    await s.journal.addTodo('오늘 것', today);
    await s.journal.addTodo('내일 것', addDaysKey(today, 1));
    await s.journal.addTodo('끝낸 것', today);
    await s.vm.toggle(s.journal.todos.last);
    expect(s.vm.overdue.map((t) => t.text), ['어제 것']);
    expect(s.vm.todayOpen.map((t) => t.text), ['오늘 것']);
    expect(s.vm.upcoming.map((t) => t.text), ['내일 것']);
    expect(s.vm.done.map((t) => t.text), ['끝낸 것']);
    expect(s.vm.openCount, 3);
  });

  test('지난 투두를 오늘로 옮기고 완료 항목을 한 번에 지울 수 있다', () async {
    final s = await _setup();
    final today = todayKey();
    await s.journal.addTodo('밀린 일', addDaysKey(today, -3));
    await s.vm.moveToToday(s.journal.todos.single);
    expect(s.vm.overdue, isEmpty);
    expect(s.vm.todayOpen.single.text, '밀린 일');
    await s.vm.toggle(s.journal.todos.single);
    await s.vm.clearDone();
    expect(s.journal.todos, isEmpty);
  });
}
