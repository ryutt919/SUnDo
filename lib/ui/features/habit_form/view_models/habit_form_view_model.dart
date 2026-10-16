import 'package:flutter/foundation.dart';

import '../../../../data/repositories/routine_repository.dart';
import '../../../../domain/models/date_key.dart';
import '../../../../domain/models/habit.dart';
import '../../../../domain/models/id.dart';
import '../../../../domain/models/repeat_rule.dart';

class HabitFormViewModel extends ChangeNotifier {
  HabitFormViewModel(this._routine, {String? habitId, Habit? template, RepeatRule? initialRepeat})
      : _original = habitId == null ? null : _routine.habitById(habitId) {
    final h = _original ?? template;
    name = h?.name ?? '';
    emoji = h?.emoji ?? '✅';
    time = h?.time ?? '';
    context = h?.context ?? '';
    color = h?.color ?? habitColors[3];
    repeat = h?.repeat ?? initialRepeat ?? const RepeatRule();
    levels = Map.of(h?.levels ?? const {'mini': '', 'plus': '', 'max': ''});
    alts = (h?.alts ?? const []).join(', ');
    alarm = h?.alarm ?? '';
    unit = h?.unit ?? '';
    timerMin = h?.timerMin ?? 0;
    modes = List.of(h?.modes ?? const []);
    reason = h?.reason ?? '';
  }

  final RoutineRepository _routine;
  final Habit? _original;

  bool get isNew => _original == null;
  List<dynamic> get availableModes => _routine.modes;

  late String name;
  late String emoji;
  late String time;
  late String context;
  late String color;
  late RepeatRule repeat;
  late Map<String, String> levels;
  late String alts;
  late String alarm;
  late String unit;
  late int timerMin;
  late List<String> modes;
  late String reason;

  void update(void Function() edit) {
    edit();
    notifyListeners();
  }

  void toggleMode(String id, bool on) => update(() => on ? modes.add(id) : modes.remove(id));

  void toggleWeekday(int d, bool on) {
    final days = List.of(repeat.days);
    on ? days.add(d) : days.remove(d);
    update(() => repeat = repeat.copyWith(days: days.toSet().toList()..sort()));
  }

  /// 입력 검증. 문제가 있으면 사용자에게 보여 줄 메시지를 돌려준다.
  String? validate() {
    if (name.trim().isEmpty) return '이름을 입력해 주세요';
    if (repeat.type == RepeatType.weekdays && repeat.days.isEmpty) return '요일을 하나 이상 골라 주세요';
    if (repeat.type == RepeatType.monthDays && repeat.monthDays.isEmpty) return '매월 날짜를 입력해 주세요';
    return null;
  }

  Future<void> save() async {
    final altList = alts.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final base = _original;
    final h = Habit(
      id: base?.id ?? newId(),
      name: name.trim(),
      emoji: emoji.trim().isEmpty ? '✅' : emoji.trim(),
      time: time,
      context: context.trim(),
      color: color,
      repeat: repeat,
      levels: levels,
      alts: altList,
      alarm: alarm,
      unit: unit.trim(),
      timerMin: timerMin,
      modes: modes,
      archived: base?.archived ?? false,
      start: base?.start ?? todayKey(),
      reason: reason.trim(),
      finishedOn: base?.finishedOn,
    );
    if (base == null) {
      await _routine.addHabit(h);
    } else {
      await _routine.updateHabit(h);
    }
  }

  Future<void> archive() async {
    final b = _original;
    // 어제까지만 나타나게 해서, 보관해도 과거 달성률과 신호등이 바뀌지 않게 한다.
    // 이미 종료한 습관이면 그 종료일을 유지해서 과거 의무일이 늘어나지 않게 한다.
    if (b != null) {
      await _routine.updateHabit(b.copyWith(archived: true, finishedOn: b.finishedOn ?? addDaysKey(todayKey(), -1)));
    }
  }

  /// 오늘까지만 하고 종료한다. 기록은 남는다.
  Future<void> finishToday() async {
    final b = _original;
    if (b != null) await _routine.updateHabit(b.copyWith(finishedOn: todayKey()));
  }

  Future<void> duplicate() async {
    final b = _original;
    if (b != null) await _routine.duplicateHabit(b.id);
  }

  Future<void> delete() async {
    final b = _original;
    if (b != null) await _routine.deleteHabit(b.id);
  }
}
