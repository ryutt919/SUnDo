import 'dart:async';

import 'package:image_picker/image_picker.dart';

import '../../../../data/repositories/routine_repository.dart';
import '../../../../data/services/photo_service.dart';
import '../../../../domain/models/habit.dart';
import '../../../../domain/models/journal_models.dart';
import '../../../../domain/use_cases/routine_analyzer.dart';
import '../../../../domain/use_cases/stats_use_case.dart';
import '../../../core/repo_view_model.dart';

/// 한 습관의 하루 상세: 난이도, 대체 이름, 수치, 사진 인증, 타이머.
class HabitDetailViewModel extends RepoViewModel {
  HabitDetailViewModel({
    required RoutineRepository routine,
    required RoutineAnalyzer analyzer,
    required StatsUseCase stats,
    required PhotoService photos,
    required this.habitId,
    required this.date,
  })  : _routine = routine,
        _analyzer = analyzer,
        _stats = stats,
        _photos = photos,
        super([routine]);

  final RoutineRepository _routine;
  final RoutineAnalyzer _analyzer;
  final StatsUseCase _stats;
  final PhotoService _photos;
  final String habitId;
  final String date;

  Timer? _timer;
  int? _secondsLeft;
  bool timerFinished = false;

  Habit? get habit => _routine.habitById(habitId);
  HabitLog get log => _routine.logOf(habitId, date) ?? const HabitLog();
  int get streak => habit == null ? 0 : _analyzer.habitStreak(habit!);
  int? get secondsLeft => _secondsLeft;
  bool get timerRunning => _timer?.isActive ?? false;
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

  // ---- 타이머 ----
  void startTimer() {
    final h = habit;
    if (h == null || h.timerMin <= 0) return;
    _timer?.cancel();
    timerFinished = false;
    _secondsLeft ??= h.timerMin * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      _secondsLeft = (_secondsLeft ?? 0) - 1;
      if (_secondsLeft! <= 0) {
        t.cancel();
        _secondsLeft = null;
        timerFinished = true;
        await _routine.setDone(habitId, date, true);
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void pauseTimer() {
    _timer?.cancel();
    notifyListeners();
  }

  void resetTimer() {
    _timer?.cancel();
    _secondsLeft = null;
    timerFinished = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
