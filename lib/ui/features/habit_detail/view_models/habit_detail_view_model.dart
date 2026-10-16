import 'package:image_picker/image_picker.dart';

import '../../../../data/repositories/routine_repository.dart';
import '../../../../data/services/photo_service.dart';
import '../../../../domain/models/habit.dart';
import '../../../../domain/models/journal_models.dart';
import '../../../../domain/use_cases/routine_analyzer.dart';
import '../../../../domain/use_cases/stats_use_case.dart';
import '../../../core/habit_timer_manager.dart';
import '../../../core/repo_view_model.dart';

/// 한 습관의 하루 상세: 난이도, 대체 이름, 수치, 사진 인증, 타이머.
/// 타이머 상태는 시트보다 오래 사는 [HabitTimerManager]가 들고 있어서, 시트를 닫아도 계속 흐른다.
class HabitDetailViewModel extends RepoViewModel {
  HabitDetailViewModel({
    required RoutineRepository routine,
    required RoutineAnalyzer analyzer,
    required StatsUseCase stats,
    required PhotoService photos,
    required HabitTimerManager timers,
    required this.habitId,
    required this.date,
  })  : _routine = routine,
        _analyzer = analyzer,
        _stats = stats,
        _photos = photos,
        _timers = timers,
        super([routine, timers]);

  final RoutineRepository _routine;
  final RoutineAnalyzer _analyzer;
  final StatsUseCase _stats;
  final PhotoService _photos;
  final HabitTimerManager _timers;
  final String habitId;
  final String date;

  Habit? get habit => _routine.habitById(habitId);
  HabitLog get log => _routine.logOf(habitId, date) ?? const HabitLog();
  int get streak => habit == null ? 0 : _analyzer.habitStreak(habit!);
  List<(String, double)> get valueSeries => _stats.valueSeries(habitId);

  Future<void> setLevel(HabitLevel l) {
    final same = log.level == l.name;
    return _routine.updateLog(habitId, date, (x) => same ? x.copyWith(clearLevel: true) : x.copyWith(level: l.name, done: true));
  }

  Future<void> setAlt(String alt) => _routine.updateLog(habitId, date, (x) => x.copyWith(alt: alt));

  Future<void> setValue(String text) {
    final v = double.tryParse(text.trim());
    return _routine.updateLog(
      habitId,
      date,
      (x) => v == null ? x.copyWith(clearValue: true) : x.copyWith(value: v, done: true),
    );
  }

  Future<void> attachPhoto(ImageSource source) async {
    final path = await _photos.pick(source);
    if (path == null) return;
    final old = log.photo;
    await _routine.updateLog(habitId, date, (x) => x.copyWith(photo: path, done: true));
    if (old != null) await _photos.delete(old);
  }

  Future<void> removePhoto() async {
    final old = log.photo;
    await _routine.updateLog(habitId, date, (x) => x.copyWith(clearPhoto: true));
    if (old != null) await _photos.delete(old);
  }

  Future<void> toggleDone() => _routine.toggle(habitId, date);

  // ---- 타이머 (상태는 HabitTimerManager가 보관) ----
  int? get secondsLeft => _timers.secondsLeft(habitId, date);
  bool get timerRunning => _timers.isRunning(habitId, date);
  bool get timerFinished => _timers.isFinished(habitId, date);

  void startTimer() {
    final h = habit;
    if (h != null) _timers.start(habitId, date, h.timerMin);
  }

  void pauseTimer() => _timers.pause(habitId, date);

  void resetTimer() => _timers.reset(habitId, date);
}
