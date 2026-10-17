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
  test('투두 탭에는 오늘과 오늘 이후만 보이고 지난 날짜는 자동으로 안 보이지만 저장소에는 남는다', () async {
    final s = await _setup();
    final today = todayKey();
    await s.journal.addTodo('어제 미완료', addDaysKey(today, -1));
    await s.journal.addTodo('어제 완료', addDaysKey(today, -1), done: true);
    await s.journal.addTodo('오늘 것', today);
    await s.journal.addTodo('내일 것', addDaysKey(today, 1));
    await s.journal.addTodo('오늘 끝낸 것', today, done: true);
    expect(s.vm.todayOpen.map((t) => t.text), ['오늘 것']);
    expect(s.vm.upcoming.map((t) => t.text), ['내일 것']);
    expect(s.vm.done.map((t) => t.text), ['오늘 끝낸 것'], reason: '지난 날의 완료 투두는 안 보인다');
    expect(s.vm.openCount, 2, reason: '지난 미완료는 남은 개수에 세지 않는다');
    expect(s.vm.manageList.map((t) => t.text), ['오늘 것', '내일 것', '오늘 끝낸 것']);
    expect(s.journal.todos.length, 5, reason: '안 보일 뿐 지워지지 않는다');
  });

  test('완료 숨기기는 지우지 않고 목록에서만 감추며, 통계에는 그대로 남는다', () async {
    final s = await _setup();
    final today = todayKey();
    await s.journal.addTodo('끝낸 일', today, done: true);
    await s.journal.addTodo('끝낸 일2', addDaysKey(today, 2), done: true);
    await s.journal.addTodo('남은 일', today);
    expect(await s.vm.hideDone(), 2);
    expect(s.vm.done, isEmpty);
    expect(s.vm.todayOpen.map((t) => t.text), ['남은 일']);
    expect(s.journal.todos.length, 3, reason: '지워지지 않는다');
    expect(s.journal.todos.where((t) => t.hidden).length, 2);
    expect(s.journal.visibleTodos.map((t) => t.text), ['남은 일']);
    // 다시 읽어도 숨김 상태가 유지된다
    final again = JournalRepository(await StorageService.create());
    await again.load();
    expect(again.todos.where((t) => t.hidden).length, 2);
    // 숨겨도 통계 캘린더의 달 합계에는 남는다(통계 테스트에서 확인)
    expect(await s.vm.hideDone(), 0, reason: '더 숨길 것이 없다');
  });
}
