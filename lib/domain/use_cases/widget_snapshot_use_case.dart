import '../../data/repositories/journal_repository.dart';
import '../../data/repositories/routine_repository.dart';
import '../models/date_key.dart';
import '../models/journal_models.dart';
import 'routine_analyzer.dart';

/// 홈 화면 위젯이 그릴 데이터를 JSON으로 만든다. 네이티브(Kotlin) 위젯이 이 형식을 읽는다.
class WidgetSnapshotUseCase {
  WidgetSnapshotUseCase(this._routine, this._analyzer, {JournalRepository? journal}) : _journal = journal;

  final RoutineRepository _routine;
  final RoutineAnalyzer _analyzer;
  final JournalRepository? _journal;

  static const maxRows = 8;

  /// 투두가 있을 때 위젯 행 중 투두에 남겨 두는 최대 칸 수(나머지는 습관).
  static const maxTodoRows = 3;

  /// 위젯에 보일 투두: 오늘 투두와 지난 미완료 투두. 안 한 것이 먼저.
  List<Todo> _widgetTodos(String today) {
    final all = _journal?.todos ?? const <Todo>[];
    final list = all.where((t) => t.date == today || (!t.done && t.date.compareTo(today) < 0)).toList();
    return [...list.where((t) => !t.done), ...list.where((t) => t.done)];
  }

  Map<String, dynamic> build() {
    final today = _analyzer.today;
    final st = _analyzer.dayStat(today);
    final due = _analyzer.dueHabits(today);
    final pct = st.rate == null ? 0 : (st.rate! * 100).round();
    final todos = _widgetTodos(today);
    final todoSlots = todos.length < maxTodoRows ? todos.length : maxTodoRows;
    final habitSlots = maxRows - todoSlots;
    final shownTodos = todos.take(todoSlots).toList();

    final ws = weekStartKey(today);
    final week = [
      for (var i = 0; i < 7; i++)
        () {
          final d = addDaysKey(ws, i);
          final s = _analyzer.dayStat(d);
          return {
            'label': koWeekdays[sundayZero(parseDateKey(d))],
            'day': parseDateKey(d).day,
            'light': _analyzer.lightOf(s, d).name,
            'today': d == today,
          };
        }()
    ];

    final now = parseDateKey(today);
    final first = DateTime(now.year, now.month, 1);
    final monthLen = DateTime(now.year, now.month + 1, 0).day;
    final month = {
      'label': '${now.year}년 ${now.month}월',
      'offset': first.weekday - 1, // 월요일 시작 달력에서 1일이 놓일 칸
      'days': [
        for (var d = 1; d <= monthLen; d++)
          () {
            final key = dateKey(DateTime(now.year, now.month, d));
            return {
              'day': d,
              'light': _analyzer.lightOf(_analyzer.dayStat(key), key).name,
              'today': key == today,
            };
          }()
      ],
    };

    return {
      'month': month,
      'date': today,
      'pct': pct,
      'done': st.done,
      'due': st.due,
      'rest': st.rest,
      'light': _analyzer.lightOf(st, today).name,
      'streak': _analyzer.streak(),
      'more': (due.length > habitSlots ? due.length - habitSlots : 0) + (todos.length - shownTodos.length),
      'rows': [
        for (final h in due.take(habitSlots))
          {
            'kind': 'habit',
            'id': h.id,
            'emoji': h.emoji,
            'name': h.name,
            'time': h.time.isNotEmpty ? h.time : h.context,
            'done': _routine.isDone(h.id, today),
            'color': h.color,
          },
        for (final t in shownTodos)
          {
            'kind': 'todo',
            'id': t.id,
            'emoji': '✔',
            'name': t.text,
            'time': t.date == today ? '투두' : '투두 ${t.date.substring(5)} 이월',
            'done': t.done,
            'color': '#E3F0FF',
          },
      ],
      'week': week,
    };
  }
}
