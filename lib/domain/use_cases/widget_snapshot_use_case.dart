import '../../data/repositories/journal_repository.dart';
import '../../data/repositories/routine_repository.dart';
import '../models/date_key.dart';
import '../models/journal_models.dart';
import '../models/repeat_rule.dart';
import 'routine_analyzer.dart';

/// 홈 화면 위젯이 그릴 데이터를 JSON으로 만든다. 네이티브(Kotlin) 위젯이 이 형식을 읽는다.
/// 위젯 안에서 스크롤해 볼 수 있도록 루틴과 투두는 개수 제한 없이 모두 담는다.
class WidgetSnapshotUseCase {
  WidgetSnapshotUseCase(this._routine, this._analyzer, {JournalRepository? journal}) : _journal = journal;

  final RoutineRepository _routine;
  final RoutineAnalyzer _analyzer;
  final JournalRepository? _journal;

  /// 위젯에 보일 투두: 오늘 투두와 지난 미완료 투두. 안 한 것이 먼저.
  List<Todo> _widgetTodos(String today) {
    final all = _journal?.todos ?? const <Todo>[];
    final list = sortTodos(all.where((t) => t.date == today || (!t.done && t.date.compareTo(today) < 0)));
    return [...list.where((t) => !t.done), ...list.where((t) => t.done)];
  }

  /// 위젯 행에 보일 투두의 날짜와 시간 문구: "오늘", "오늘 14:30", "10-16 이월 14:30".
  static String _todoWhen(Todo t, String today) {
    final base = t.date == today ? '오늘' : '${t.date.substring(5)} 이월';
    return t.hasTime ? '$base ${t.time}' : base;
  }

  Map<String, dynamic> build() {
    final today = _analyzer.today;
    final st = _analyzer.dayStat(today);
    final due = _analyzer.dueHabits(today);
    final pct = st.rate == null ? 0 : (st.rate! * 100).round();
    // 오늘 아직 채워야 하는 주간 루틴은 매일 루틴 뒤에 붙인다(오늘 체크한 것은 목표를 채워도 계속 보인다)
    final weekly = [
      for (final h in _analyzer.weeklyHabits(today))
        if (_analyzer.isDue(h, today)) h
    ];
    final habits = [...due, ...weekly];
    final todos = _widgetTodos(today);
    final todoDone = todos.where((t) => t.done).length;

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
      'rows': [
        for (final h in habits)
          {
            'kind': 'habit',
            'id': h.id,
            'emoji': h.emoji,
            'name': h.name,
            'time': h.repeat.type == RepeatType.weekly
                ? '주 ${h.repeat.times}회 중 ${_analyzer.weeklyProgress(h, today).doneCount}'
                : (h.time.isNotEmpty ? h.time : h.context),
            'done': _routine.isDone(h.id, today),
            'color': h.color,
          }
      ],
      'todoDone': todoDone,
      'todoTotal': todos.length,
      'todos': [
        for (final t in todos)
          {
            'kind': 'todo',
            'id': t.id,
            'emoji': '✔',
            'name': t.text,
            'time': _todoWhen(t, today),
            'done': t.done,
            'color': '#DDF1FF',
          },
      ],
      'week': week,
    };
  }
}
