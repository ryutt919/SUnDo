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

  Future<void> addItem(Goal g, String text) =>
      _journal.saveGoal(g.copyWith(items: [...g.items, GoalItem(text: text)]));

  Future<void> toggleItem(Goal g, int index) => _journal.saveGoal(g.copyWith(
        items: [for (var i = 0; i < g.items.length; i++) i == index ? g.items[i].copyWith(done: !g.items[i].done) : g.items[i]],
      ));

  Future<void> removeItem(Goal g, int index) =>
      _journal.saveGoal(g.copyWith(items: [for (var i = 0; i < g.items.length; i++) if (i != index) g.items[i]]));

  Future<void> deleteGoal(String id) => _journal.deleteGoal(id);
}
