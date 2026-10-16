import '../../../../data/repositories/journal_repository.dart';
import '../../../../domain/models/date_key.dart';
import '../../../../domain/models/id.dart';
import '../../../../domain/models/journal_models.dart';
import '../../../core/repo_view_model.dart';

/// 주간, 월간, 연간 계획. 계획마다 체크리스트 항목이 있고 진행률이 계산된다.
class GoalsViewModel extends RepoViewModel {
  GoalsViewModel(this._journal) : super([_journal]) {
    anchor = todayKey();
  }

  final JournalRepository _journal;

  GoalPeriod period = GoalPeriod.week;
  late String anchor; // 보고 있는 기간 안의 아무 날짜

  String get periodKey {
    final d = parseDateKey(anchor);
    return switch (period) {
      GoalPeriod.week => weekStartKey(anchor),
      GoalPeriod.month => '${d.year}-${d.month.toString().padLeft(2, '0')}',
      GoalPeriod.year => '${d.year}',
    };
  }

  String get periodTitle {
    final d = parseDateKey(anchor);
    return switch (period) {
      GoalPeriod.week => '${weekStartKey(anchor).substring(5)} 주',
      GoalPeriod.month => '${d.year}년 ${d.month}월',
      GoalPeriod.year => '${d.year}년',
    };
  }

  List<Goal> get goals => _journal.goalsFor(period, periodKey);

  /// 아직 끝내지 않은 계획과 완료한 계획(완료한 것은 아래쪽에 따로 보인다).
  List<Goal> get openGoals => goals.where((g) => !g.done).toList();
  List<Goal> get doneGoals => goals.where((g) => g.done).toList();

  double get overallProgress {
    final g = goals;
    if (g.isEmpty) return 0;
    return g.fold(0.0, (a, x) => a + x.progress) / g.length;
  }

  void setPeriod(GoalPeriod p) {
    period = p;
    notifyListeners();
  }

  void shift(int delta) {
    final d = parseDateKey(anchor);
    anchor = switch (period) {
      GoalPeriod.week => addDaysKey(anchor, 7 * delta),
      GoalPeriod.month => dateKey(DateTime(d.year, d.month + delta, 1)),
      GoalPeriod.year => dateKey(DateTime(d.year + delta, 1, 1)),
    };
    notifyListeners();
  }

  void goCurrent() {
    anchor = todayKey();
    notifyListeners();
  }

  Future<void> addGoal(String title) =>
      _journal.saveGoal(Goal(id: newId(), title: title, period: period, periodKey: periodKey));

  Future<void> rename(Goal g, String title) => _journal.saveGoal(g.copyWith(title: title));

  /// 새 세부 항목은 아직 안 끝난 일이라 완료였던 계획도 다시 진행 중이 된다.
  Future<void> addItem(Goal g, String text) =>
      _journal.saveGoal(g.copyWith(items: [...g.items, GoalItem(text: text)], done: false));

  /// 계획 전체를 완료로 체크하면 세부 항목도 모두 끝낸 것으로 하고, 체크를 풀면 계획만 진행 중으로 돌린다.
  Future<void> toggleGoal(Goal g) => _journal.saveGoal(g.done
      ? g.copyWith(done: false)
      : g.copyWith(done: true, items: [for (final i in g.items) i.copyWith(done: true)]));

  /// 세부 항목을 모두 끝내면 계획이 완료가 되고, 하나라도 풀면 진행 중으로 돌아간다.
  Future<void> toggleItem(Goal g, int index) {
    final items = [for (var i = 0; i < g.items.length; i++) i == index ? g.items[i].copyWith(done: !g.items[i].done) : g.items[i]];
    return _journal.saveGoal(g.copyWith(items: items, done: items.isNotEmpty && items.every((i) => i.done)));
  }

  Future<void> removeItem(Goal g, int index) {
    final items = [for (var i = 0; i < g.items.length; i++) if (i != index) g.items[i]];
    // 마지막 남은 미완료 항목을 지우면 나머지가 모두 완료여서 계획도 완료가 된다
    return _journal.saveGoal(g.copyWith(items: items, done: g.done || (items.isNotEmpty && items.every((i) => i.done))));
  }

  /// 이 기간에서 완료한 계획 수와 전체 수.
  ({int done, int total}) get completion => (done: doneGoals.length, total: goals.length);

  Future<void> deleteGoal(String id) => _journal.deleteGoal(id);
}
