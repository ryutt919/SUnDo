import '../../../../data/repositories/journal_repository.dart';
import '../../../../data/repositories/routine_repository.dart';
import '../../../../domain/models/date_key.dart';
import '../../../../domain/models/id.dart';
import '../../../../domain/models/journal_models.dart';
import '../../../../domain/use_cases/routine_analyzer.dart';
import '../../../core/repo_view_model.dart';

/// 회고 탭: 기분, 데일리 회고, 주차 회고, 메모.
class ReviewViewModel extends RepoViewModel {
  ReviewViewModel({
    required JournalRepository journal,
    required RoutineRepository routine,
    required RoutineAnalyzer analyzer,
  })  : _journal = journal,
        _analyzer = analyzer,
        super([journal, routine]);

  final JournalRepository _journal;
  final RoutineAnalyzer _analyzer;

  static String weekKey(String date) => 'w:${weekStartKey(date)}';

  DayReview reviewOf(String date) => _journal.reviewOf(date);
  DayReview weekReviewOf(String date) => _journal.reviewOf(weekKey(date));
  List<Memo> memosOf(String date) => _journal.memosOf(date);
  DayStat statOf(String date) => _analyzer.dayStat(date);

  Future<void> setMood(String date, int mood) {
    final r = reviewOf(date);
    return _journal.saveReview(date, r.copyWith(mood: r.mood == mood ? 0 : mood));
  }

  Future<void> setBest(String date, String v) => _journal.saveReview(date, reviewOf(date).copyWith(best: v));

  Future<void> setMsg(String date, String v) => _journal.saveReview(date, reviewOf(date).copyWith(msg: v));

  Future<void> setWeekBest(String date, String v) =>
      _journal.saveReview(weekKey(date), weekReviewOf(date).copyWith(best: v));

  Future<void> setWeekMsg(String date, String v) =>
      _journal.saveReview(weekKey(date), weekReviewOf(date).copyWith(msg: v));

  Future<void> saveMemo({String? id, required String date, required MemoKind kind, required String text, required bool hl}) =>
      _journal.saveMemo(Memo(id: id ?? newId(), date: date, kind: kind, text: text, hl: hl));

  Future<void> deleteMemo(String id) => _journal.deleteMemo(id);
}
