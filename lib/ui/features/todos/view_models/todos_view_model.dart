import '../../../../data/repositories/journal_repository.dart';
import '../../../../domain/models/date_key.dart';
import '../../../../domain/models/journal_models.dart';
import '../../../core/repo_view_model.dart';

/// 투두 탭: 전체 투두를 지난 미완료 / 오늘 / 예정 / 완료로 나눠 보여 준다.
class TodosViewModel extends RepoViewModel {
  TodosViewModel(this._journal) : super([_journal]);

  final JournalRepository _journal;

  String get today => dateKey(DateTime.now());

  List<Todo> get _all => _journal.todos;

  /// 오늘보다 앞선 날짜에 남은 미완료 투두. 날짜가 오래된 것부터.
  List<Todo> get overdue => sortTodos(_all.where((t) => !t.done && t.date.compareTo(today) < 0));

  /// 오늘 미완료 투두. 시간이 있는 것을 시간 순으로 먼저.
  List<Todo> get todayOpen => sortTodos(_all.where((t) => !t.done && t.date == today));

  /// 오늘 이후 날짜의 미완료 투두. 가까운 날짜부터.
  List<Todo> get upcoming => sortTodos(_all.where((t) => !t.done && t.date.compareTo(today) > 0));

  /// 완료한 투두. 최근 날짜부터.
  List<Todo> get done => sortTodos(_all.where((t) => t.done), newestFirst: true);

  /// 일괄 삭제 화면에 보일 전체 투두(남은 것은 날짜 순, 완료는 뒤).
  List<Todo> get manageList => [...overdue, ...todayOpen, ...upcoming, ...done];

  int get openCount => overdue.length + todayOpen.length + upcoming.length;

  Future<void> toggle(Todo t) => _journal.updateTodo(t.copyWith(done: !t.done));

  Future<void> delete(Todo t) => _journal.deleteTodo(t.id);

  Future<void> deleteMany(Set<String> ids) => _journal.deleteTodos(ids);

  /// 오늘로 옮긴다(지난 미완료 정리용).
  Future<void> moveToToday(Todo t) => _journal.updateTodo(t.copyWith(date: today));

  Future<void> clearDone() async {
    for (final t in done) {
      await _journal.deleteTodo(t.id);
    }
  }
}
