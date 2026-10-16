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
  List<Todo> get overdue =>
      (_all.where((t) => !t.done && t.date.compareTo(today) < 0).toList()..sort((a, b) => a.date.compareTo(b.date)));

  List<Todo> get todayOpen => _all.where((t) => !t.done && t.date == today).toList();

  /// 오늘 이후 날짜의 미완료 투두. 가까운 날짜부터.
  List<Todo> get upcoming =>
      (_all.where((t) => !t.done && t.date.compareTo(today) > 0).toList()..sort((a, b) => a.date.compareTo(b.date)));

  /// 완료한 투두. 최근 날짜부터.
  List<Todo> get done =>
      (_all.where((t) => t.done).toList()..sort((a, b) => b.date.compareTo(a.date)));

  int get openCount => overdue.length + todayOpen.length + upcoming.length;

  Future<void> quickAdd(String text) {
    final t = text.trim();
    if (t.isEmpty) return Future.value();
    return _journal.addTodo(t, today);
  }

  Future<void> toggle(Todo t) => _journal.updateTodo(t.copyWith(done: !t.done));

  Future<void> delete(Todo t) => _journal.deleteTodo(t.id);

  /// 오늘로 옮긴다(지난 미완료 정리용).
  Future<void> moveToToday(Todo t) => _journal.updateTodo(t.copyWith(date: today));

  Future<void> clearDone() async {
    for (final t in done) {
      await _journal.deleteTodo(t.id);
    }
  }
}
