import '../../data/repositories/routine_repository.dart';
import '../models/date_key.dart';
import 'routine_analyzer.dart';

/// 홈 화면 위젯이 그릴 데이터를 JSON으로 만든다. 네이티브(Kotlin) 위젯이 이 형식을 읽는다.
class WidgetSnapshotUseCase {
  WidgetSnapshotUseCase(this._routine, this._analyzer);

  final RoutineRepository _routine;
  final RoutineAnalyzer _analyzer;

  static const maxRows = 8;

  Map<String, dynamic> build() {
    final today = _analyzer.today;
    final st = _analyzer.dayStat(today);
    final due = _analyzer.dueHabits(today);
    final pct = st.rate == null ? 0 : (st.rate! * 100).round();

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
      'more': due.length > maxRows ? due.length - maxRows : 0,
      'rows': [
        for (final h in due.take(maxRows))
          {
            'id': h.id,
            'emoji': h.emoji,
            'name': h.name,
            'time': h.time.isNotEmpty ? h.time : h.context,
            'done': _routine.isDone(h.id, today),
            'color': h.color,
          }
      ],
      'week': week,
    };
  }
}
