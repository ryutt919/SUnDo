import '../../data/repositories/routine_repository.dart';
import '../models/date_key.dart';
import 'routine_analyzer.dart';

class AlarmSpec {
  const AlarmSpec({required this.id, required this.title, required this.body, required this.at});
  final int id;
  final String title;
  final String body;
  final DateTime at;
}

/// 앞으로 며칠 동안 울려야 할 습관 알람 목록을 만든다.
/// 반복 규칙(요일, N일마다 등)을 지켜서, 해야 하는 날에만 알람을 만든다.
class AlarmPlanUseCase {
  AlarmPlanUseCase(this._routine, this._analyzer);

  final RoutineRepository _routine;
  final RoutineAnalyzer _analyzer;

  static const horizonDays = 14;

  /// [morning], [evening]은 'HH:mm' (빈 문자열이면 끔). 쉬는 날에는 울리지 않는다.
  List<AlarmSpec> build({DateTime? now, String morning = '', String evening = ''}) {
    final n = now ?? DateTime.now();
    final startKey = dateKey(n);
    final out = <AlarmSpec>[];
    for (var i = 0; i < horizonDays; i++) {
      final key = addDaysKey(startKey, i);
      if (_routine.isRest(key)) continue;
      final due = _analyzer.dueHabits(key).length;
      final m = _at(key, morning);
      if (m != null && m.isAfter(n) && due > 0) {
        out.add(AlarmSpec(id: _stableId('morning', key), title: '좋은 아침이에요', body: '오늘의 루틴 $due개가 기다려요', at: m));
      }
      final e = _at(key, evening);
      if (e != null && e.isAfter(n)) {
        out.add(AlarmSpec(id: _stableId('evening', key), title: '오늘 하루 어땠나요?', body: '루틴을 확인하고 회고를 남겨 보세요', at: e));
      }
    }
    for (final h in _routine.habits) {
      if (h.alarm.isEmpty || h.archived || !_analyzer.inActiveMode(h)) continue;
      final parts = h.alarm.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;
      for (var i = 0; i < horizonDays; i++) {
        final key = addDaysKey(startKey, i);
        if (_routine.isRest(key) || !_analyzer.isDue(h, key)) continue;
        if (_routine.isDone(h.id, key)) continue;
        final d = parseDateKey(key);
        final at = DateTime(d.year, d.month, d.day, hour, minute);
        if (!at.isAfter(n)) continue;
        out.add(AlarmSpec(
          id: _stableId(h.id, key),
          title: '${h.emoji} ${h.name}',
          body: h.context.isNotEmpty ? h.context : '지금 할 시간이에요',
          at: at,
        ));
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  static DateTime? _at(String key, String hhmm) {
    final p = hhmm.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    final d = parseDateKey(key);
    return DateTime(d.year, d.month, d.day, h, m);
  }

  static int _stableId(String habitId, String date) {
    var h = 0;
    for (final c in '$habitId|$date'.codeUnits) {
      h = (h * 31 + c) & 0x3fffffff;
    }
    return h;
  }
}
