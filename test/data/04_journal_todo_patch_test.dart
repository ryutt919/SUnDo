// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:my_routine/data/repositories/journal_repository.dart';
import 'package:my_routine/data/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<JournalRepository> setup() async {
    SharedPreferences.setMockInitialValues({});
    final journal = JournalRepository(await StorageService.create());
    await journal.load();
    return journal;
  }

  test('필드 수정은 다른 인스턴스의 완료와 숨김 상태를 유지한다', () async {
    final journal = await setup();
    final todo = await journal.addTodo('회의', '2026-10-21', time: '14:30');
    final other = JournalRepository(await StorageService.create());
    await other.load();
    await other.updateTodo(todo.copyWith(done: true, hidden: true));
    final patched = await journal.patchTodo(
      todo.id,
      text: '업무 회의',
      time: '16:00',
    );
    expect(patched!.text, '업무 회의');
    expect(patched.time, '16:00');
    expect(patched.done, true);
    expect(patched.hidden, true);
  });

  test('조건부 반영은 날짜와 시간을 묶어 최신 편집을 보존한다', () async {
    final journal = await setup();
    final todo = await journal.addTodo('회의', '2026-10-21', time: '14:30');
    await journal.updateTodo(todo.copyWith(date: '2026-10-22', done: true));
    final patched = await journal.patchTodo(
      todo.id,
      expected: todo,
      text: '외부 회의',
      date: '2026-10-23',
      time: '17:00',
      done: false,
    );
    expect(patched!.text, '외부 회의');
    expect(patched.date, '2026-10-22');
    expect(patched.time, '14:30');
    expect(patched.done, true);
  });

  test('삭제된 투두는 필드 반영으로 되살리지 않는다', () async {
    final journal = await setup();
    final todo = await journal.addTodo('회의', '2026-10-21');
    await journal.deleteTodo(todo.id);
    expect(await journal.patchTodo(todo.id, time: '16:00'), isNull);
    expect(journal.todos, isEmpty);
  });

  test('빈 시간은 종일 전환으로 저장된다', () async {
    final journal = await setup();
    final todo = await journal.addTodo('회의', '2026-10-21', time: '14:30');
    final patched = await journal.patchTodo(todo.id, time: '');
    expect(patched!.time, '');
    final reloaded = JournalRepository(await StorageService.create());
    await reloaded.load();
    expect(reloaded.todos.single.time, '');
  });
  test('외부 삭제를 기다리는 동안 바꾼 투두는 보존한다', () async {
    final journal = await setup();
    final todo = await journal.addTodo('회의', '2026-10-21');
    await journal.patchTodo(todo.id, done: true);
    expect(await journal.deleteTodoIfUnchanged(todo.id, todo), false);
    expect(journal.todos.single.done, true);
  });

  test('외부 삭제는 변경되지 않은 투두에만 반영한다', () async {
    final journal = await setup();
    final todo = await journal.addTodo('회의', '2026-10-21');
    expect(await journal.deleteTodoIfUnchanged(todo.id, todo), true);
    expect(journal.todos, isEmpty);
    expect(await journal.deleteTodoIfUnchanged(todo.id, todo), false);
  });
}
