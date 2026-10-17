import '../../../../data/repositories/journal_repository.dart';
import '../../../../domain/models/date_key.dart';
import '../../../../domain/models/journal_models.dart';
import '../../../core/repo_view_model.dart';

/// 투두 탭: 전체 투두를 지난 미완료 / 오늘 / 예정 / 완료로 나눠 보여 준다.
class TodosViewModel extends RepoViewModel {
  TodosViewModel(this._journal) : super([_journal]);

  final JournalRepository _journal;

  String get today => dateKey(DateTime.now());

  /// 투두 탭에는 오늘과 오늘 이후의 투두만 보인다. 지난 날짜의 투두는 자동으로 안 보이지만
  /// 지워진 것이 아니라서 통계에는 남는다. "완료 숨기기"로 감춘 투두도 마찬가지다.
  List<Todo> get _all => _journal.visibleTodos.where((t) => t.date.compareTo(today) >= 0).toList();

  /// 오늘 미완료 투두. 시간이 있는 것을 시간 순으로 먼저.
  List<Todo> get todayOpen => sortTodos(_all.where((t) => !t.done && t.date == today));

  /// 오늘 이후 날짜의 미완료 투두. 가까운 날짜부터.
  List<Todo> get upcoming => sortTodos(_all.where((t) => !t.done && t.date.compareTo(today) > 0));

  /// 오늘 이후 날짜에 이미 끝낸 투두(오늘 끝낸 것 포함). 날짜가 가까운 것부터.
  List<Todo> get done => sortTodos(_all.where((t) => t.done));

  /// 일괄 삭제 화면에 보일 투두(남은 것은 날짜 순, 완료는 뒤).
  List<Todo> get manageList => [...todayOpen, ...upcoming, ...done];

  int get openCount => todayOpen.length + upcoming.length;

  Future<void> toggle(Todo t) => _journal.updateTodo(t.copyWith(done: !t.done));

  Future<void> delete(Todo t) => _journal.deleteTodo(t.id);

  Future<void> deleteMany(Set<String> ids) => _journal.deleteTodos(ids);

  /// 끝낸 투두를 목록에서 감춘다. 지우는 것이 아니라서 통계 캘린더에는 그대로 남는다.
  /// 감춘 개수를 돌려준다.
  Future<int> hideDone() async {
    final ids = {for (final t in done) t.id};
    await _journal.hideTodos(ids);
    return ids.length;
  }
}
