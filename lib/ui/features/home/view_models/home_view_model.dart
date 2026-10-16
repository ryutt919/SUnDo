import '../../../../data/repositories/journal_repository.dart';
import '../../../../data/repositories/routine_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../domain/models/date_key.dart';
import '../../../../domain/models/habit.dart';
import '../../../../domain/models/journal_models.dart';
import '../../../../domain/use_cases/routine_analyzer.dart';
import '../../../core/repo_view_model.dart';

enum HomeTab { routine, review }

enum HomeViewMode { day, week }

enum HomeFilter { all, undone, done }

extension HomeFilterLabel on HomeFilter {
  String get label => switch (this) {
        HomeFilter.all => '전체',
        HomeFilter.undone => '미완료',
        HomeFilter.done => '완료',
      };
}

class WeekCell {
  const WeekCell({
    required this.date,
    required this.weekdayLabel,
    required this.day,
    required this.light,
    required this.selected,
    required this.isToday,
  });
  final String date;
  final String weekdayLabel;
  final int day;
  final TrafficLight light;
  final bool selected;
  final bool isToday;
}

class HabitRowData {
  const HabitRowData({
    required this.habit,
    required this.number,
    required this.done,
    required this.title,
    required this.subtitle,
  });
  final Habit habit;
  final int number;
  final bool done;
  final String title;
  final String subtitle;
}

class TodoRowData {
  const TodoRowData(this.todo, this.carriedFrom);
  final Todo todo;
  final String? carriedFrom; // 지난 날에서 이월된 투두면 그 날짜
}

class WeekGridCell {
  const WeekGridCell({required this.date, required this.due, required this.done});
  final String date;
  final bool due;
  final bool done;
}

class HomeViewModel extends RepoViewModel {
  HomeViewModel({
    required RoutineRepository routine,
    required JournalRepository journal,
    required SettingsRepository settings,
    required RoutineAnalyzer analyzer,
  })  : _routine = routine,
        _journal = journal,
        _settings = settings,
        _analyzer = analyzer,
        selectedDate = analyzer.today,
        super([routine, journal, settings]);

  final RoutineRepository _routine;
  final JournalRepository _journal;
  final SettingsRepository _settings;
  final RoutineAnalyzer _analyzer;

  String selectedDate;
  HomeTab tab = HomeTab.routine;
  HomeViewMode viewMode = HomeViewMode.day;
  HomeFilter filter = HomeFilter.all;
  bool editing = false;

  // ---- 읽기 상태 ----
  String get today => _analyzer.today;
  bool get isRestDay => _routine.isRest(selectedDate);
  RoutineMode get activeMode => _routine.activeMode;
  List<RoutineMode> get modes => _routine.modes;
  DayStat get dayStat => _analyzer.dayStat(selectedDate);
  TrafficLight get dayLight => _analyzer.lightOf(dayStat, selectedDate);
  int get percent => ((dayStat.rate ?? 0) * 100).round();
  int get streak => _analyzer.streak();
  int get routineDay => _analyzer.routineDay;

  List<WeekCell> get weekCells {
    final ws = weekStartKey(selectedDate);
    return [
      for (var i = 0; i < 7; i++)
        () {
          final d = addDaysKey(ws, i);
          final dt = parseDateKey(d);
          return WeekCell(
            date: d,
            weekdayLabel: koWeekdays[sundayZero(dt)],
            day: dt.day,
            light: _analyzer.lightOf(_analyzer.dayStat(d), d),
            selected: d == selectedDate,
            isToday: d == today,
          );
        }()
    ];
  }

  List<HabitRowData> get habitRows {
    var list = _analyzer.dueHabits(selectedDate);
    if (_settings.settings.sortByTime && !editing) {
      // 시각이 있는 습관은 시간 순으로, 시각이 없는(상황 기반) 습관은 뒤쪽에 원래 순서대로 둔다.
      final timed = list.where((h) => h.time.isNotEmpty).toList()..sort((a, b) => a.time.compareTo(b.time));
      list = [...timed, ...list.where((h) => h.time.isEmpty)];
    }
    if (!editing) {
      if (filter == HomeFilter.undone) list = list.where((h) => !_routine.isDone(h.id, selectedDate)).toList();
      if (filter == HomeFilter.done) list = list.where((h) => _routine.isDone(h.id, selectedDate)).toList();
      if (_settings.settings.doneToBottom) {
        list = [
          ...list.where((h) => !_routine.isDone(h.id, selectedDate)),
          ...list.where((h) => _routine.isDone(h.id, selectedDate)),
        ];
      }
    }
    return [
      for (var i = 0; i < list.length; i++)
        () {
          final h = list[i];
          final log = _routine.logOf(h.id, selectedDate);
          final streak = _analyzer.habitStreak(h);
          final parts = [
            if (log?.level != null) habitLevelFrom(log!.level)!.label,
            if (log?.value != null) '${_fmt(log!.value!)}${h.unit}',
            if (streak >= 2) '🔥$streak',
            if (h.alarm.isNotEmpty) '🔔${h.alarm}',
          ];
          return HabitRowData(
            habit: h,
            number: i + 1,
            done: _routine.isDone(h.id, selectedDate),
            title: (log?.alt.isNotEmpty ?? false) ? log!.alt : h.name,
            subtitle: parts.join('  '),
          );
        }()
    ];
  }

  List<TodoRowData> get todoRows {
    final isToday = selectedDate == today;
    var list = _journal.todos
        .where((t) => t.date == selectedDate || (isToday && t.date.compareTo(selectedDate) < 0 && !t.done))
        .toList();
    if (filter == HomeFilter.undone) list = list.where((t) => !t.done).toList();
    if (filter == HomeFilter.done) list = list.where((t) => t.done).toList();
    if (_settings.settings.doneToBottom) {
      list = [...list.where((t) => !t.done), ...list.where((t) => t.done)];
    }
    return [for (final t in list) TodoRowData(t, t.date.compareTo(selectedDate) < 0 ? t.date : null)];
  }

  List<Habit> get weekGridHabits =>
      _routine.habits.where((h) => !h.archived && _analyzer.inActiveMode(h)).toList();

  List<String> get weekDates {
    final ws = weekStartKey(selectedDate);
    return [for (var i = 0; i < 7; i++) addDaysKey(ws, i)];
  }

  WeekGridCell weekGridCell(Habit h, String date) => WeekGridCell(
        date: date,
        due: _analyzer.isDue(h, date),
        done: _routine.isDone(h.id, date),
      );

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  // ---- 명령 ----
  void selectDate(String date) {
    selectedDate = date;
    notifyListeners();
  }

  void shiftWeek(int delta) => selectDate(addDaysKey(selectedDate, 7 * delta));

  void goToday() => selectDate(today);

  void setTab(HomeTab t) {
    tab = t;
    notifyListeners();
  }

  void setViewMode(HomeViewMode m) {
    viewMode = m;
    notifyListeners();
  }

  void cycleFilter() {
    filter = HomeFilter.values[(filter.index + 1) % HomeFilter.values.length];
    notifyListeners();
  }

  bool get sortByTime => _settings.settings.sortByTime;

  Future<void> toggleSortByTime() =>
      _settings.update(_settings.settings.copyWith(sortByTime: !sortByTime));

  void toggleEditing() {
    editing = !editing;
    notifyListeners();
  }

  Future<void> toggleHabit(String id, [String? date]) => _routine.toggle(id, date ?? selectedDate);

  Future<void> toggleTodo(Todo t) => _journal.updateTodo(t.copyWith(done: !t.done));

  Future<void> setRest(bool rest) => _routine.setRest(selectedDate, rest);

  Future<void> setRestRange(String from, String to) => _routine.setRestRange(from, to, true);

  Future<void> applyMode(String id) => _routine.setActiveMode(id);

  Future<void> reorder(int oldIndex, int newIndex) {
    // onReorderItem은 제거 후 위치(newIndex)를 이미 보정해서 준다.
    final ids = habitRows.map((r) => r.habit.id).toList();
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);
    return _routine.reorderVisible(ids);
  }
}
