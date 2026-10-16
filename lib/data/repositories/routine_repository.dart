import 'package:flutter/foundation.dart';

import '../../domain/models/date_key.dart';
import '../../domain/models/habit.dart';
import '../../domain/models/id.dart';
import '../../domain/models/journal_models.dart';
import '../services/storage_service.dart';

class _Imported {
  const _Imported({
    required this.habits,
    required this.modes,
    required this.activeMode,
    required this.modeFrom,
    required this.modeDeleted,
    required this.logs,
    required this.rest,
  });
  final List<Habit> habits;
  final List<RoutineMode> modes;
  final String activeMode;
  final Map<String, String> modeFrom;
  final Map<String, String> modeDeleted;
  final Map<String, Map<String, HabitLog>> logs;
  final Set<String> rest;
}

/// 루틴, 일별 기록, 쉬는 날, 루틴 모드의 단일 출처.
class RoutineRepository extends ChangeNotifier {
  RoutineRepository(this._store);

  final StorageService _store;

  List<Habit> _habits = [];
  List<RoutineMode> _modes = [const RoutineMode(id: 'm1', name: '기본')];
  String _activeMode = 'm1';
  Map<String, Map<String, HabitLog>> _logs = {};
  Set<String> _rest = {};

  /// 날짜별 루틴 모드 이력: "이 날부터 이 모드". 모드를 바꿔도 지난 날의 통계가 변하지 않게 한다.
  Map<String, String> _modeFrom = {'0000-01-01': 'm1'};

  static const _modeEpoch = '0000-01-01';

  /// 지난 날 [date]에 쓰던 모드. 오늘 이후는 현재 모드를 쓰면 되므로 호출하는 쪽에서 구분한다.
  String modeOn(String date) {
    String? best;
    for (final k in _modeFrom.keys) {
      if (k.compareTo(date) <= 0 && (best == null || k.compareTo(best) > 0)) best = k;
    }
    // 삭제한 모드의 id도 그대로 돌려준다. 그래야 모드를 지워도 지난 날의 구성이 바뀌지 않는다.
    return best == null ? _activeMode : _modeFrom[best]!;
  }

  /// 지금 존재하는 모드인지(삭제되지 않았는지).
  bool hasMode(String id) => _modes.any((m) => m.id == id);

  /// 삭제한 모드가 삭제된 날짜. 삭제하지 않았으면 null.
  String? modeDeletedOn(String id) => _modeDeletedOn[id];

  /// 삭제한 모드의 id와 삭제한 날짜. 소속 모드가 모두 사라진 루틴이 언제부터 모든 모드에 나타나는지 정하는 데 쓴다.
  Map<String, String> _modeDeletedOn = {};

  List<Habit> get habits => List.unmodifiable(_habits);
  List<RoutineMode> get modes => List.unmodifiable(_modes);
  String get activeModeId => _activeMode;
  RoutineMode get activeMode =>
      _modes.firstWhere((m) => m.id == _activeMode, orElse: () => _modes.first);

  HabitLog? logOf(String habitId, String date) => _logs[date]?[habitId];
  bool isDone(String habitId, String date) => logOf(habitId, date)?.done ?? false;
  bool isRest(String date) => _rest.contains(date);
  Iterable<String> get restDates => _rest;

  int get totalChecks => _logs.values
      .fold(0, (a, day) => a + day.values.where((l) => l.done).length);

  Habit? habitById(String id) {
    for (final h in _habits) {
      if (h.id == id) return h;
    }
    return null;
  }

  Future<void> load() async {
    await _store.reload();
    if (!_store.contains('habits')) {
      _habits = _seedHabits();
      try {
        await _persistAll();
      } on StorageWriteException catch (e) {
        // 첫 실행에서 예시 루틴을 저장하지 못해도 앱은 시작한다(다음 저장 때 다시 기록된다)
        debugPrint('초기 데이터 저장 실패: $e');
      }
    } else {
      _habits = _list('habits').map(Habit.fromJson).toList();
      final modes = _list('modes').map(RoutineMode.fromJson).toList();
      if (modes.isNotEmpty) _modes = modes;
      _activeMode = _store.readString('activeMode') ?? _modes.first.id;
      if (!_modes.any((m) => m.id == _activeMode)) _activeMode = _modes.first.id;
      _logs = _parseLogs(_store.readJson('logs'));
      final rest = _store.readJson('rest');
      _rest = rest is Map ? rest.keys.map((k) => '$k').toSet() : {};
      _modeFrom = _parseModeFrom(_store.readJson('modeFrom'), _activeMode);
      _modeDeletedOn = _parseStringMap(_store.readJson('modeDeleted'));
    }
    notifyListeners();
  }

  Map<String, String> _parseStringMap(Object? raw) =>
      raw is Map ? raw.map((k, v) => MapEntry('$k', '$v')) : <String, String>{};

  Map<String, String> _parseModeFrom(Object? raw, String fallbackMode) {
    final m = raw is Map ? raw.map((k, v) => MapEntry('$k', '$v')) : <String, String>{};
    if (m.isEmpty) return {_modeEpoch: fallbackMode};
    return m;
  }

  List<Map<String, dynamic>> _list(String key) {
    final v = _store.readJson(key);
    return v is List ? v.map((e) => (e as Map).cast<String, dynamic>()).toList() : [];
  }

  Map<String, Map<String, HabitLog>> _parseLogs(Object? raw) {
    if (raw is! Map) return {};
    return raw.map((date, day) => MapEntry(
          '$date',
          (day as Map).map((id, l) =>
              MapEntry('$id', HabitLog.fromJson((l as Map).cast<String, dynamic>()))),
        ));
  }

  List<Habit> _seedHabits() {
    final t = todayKey();
    return [
      Habit(id: newId(), name: '아침에 물 한 잔', emoji: '💧', time: '07:00', color: habitColors[4], start: t),
      Habit(id: newId(), name: '스트레칭 10분', emoji: '🧘', context: '점심 먹고', color: habitColors[3], start: t),
      Habit(id: newId(), name: '책 10쪽 읽기', emoji: '📖', time: '22:00', color: habitColors[5], start: t),
    ];
  }

  Future<void> _persistAll() async {
    await _store.writeJson('habits', _habits.map((h) => h.toJson()).toList());
    await _store.writeJson('modes', _modes.map((m) => m.toJson()).toList());
    await _store.writeString('activeMode', _activeMode);
    await _store.writeJson('modeFrom', _modeFrom);
    await _store.writeJson('modeDeleted', _modeDeletedOn);
    await _persistLogs();
    await _persistRest();
  }

  Future<void> _persistLogs() => _store.writeJson(
      'logs', _logs.map((d, day) => MapEntry(d, day.map((id, l) => MapEntry(id, l.toJson())))));
  Future<void> _persistRest() => _store.writeJson('rest', {for (final d in _rest) d: true});
  Future<void> _persistHabits() =>
      _store.writeJson('habits', _habits.map((h) => h.toJson()).toList());

  // ---- 루틴 ----
  Future<void> addHabit(Habit h) async {
    _habits = [..._habits, h];
    await _persistHabits();
    notifyListeners();
  }

  Future<void> updateHabit(Habit h) async {
    _habits = [for (final x in _habits) x.id == h.id ? h : x];
    await _persistHabits();
    notifyListeners();
  }

  Future<void> duplicateHabit(String id) async {
    final h = habitById(id);
    if (h == null) return;
    await addHabit(Habit(
      id: newId(), name: '${h.name} (복사)', emoji: h.emoji, time: h.time, context: h.context,
      color: h.color, repeat: h.repeat, levels: h.levels, alts: h.alts, alarm: h.alarm,
      unit: h.unit, timerMin: h.timerMin, modes: h.modes, start: todayKey(), reason: h.reason,
    ));
  }

  Future<void> deleteHabit(String id) async {
    await _refreshLogsAndRest(); // 위젯이 방금 한 체크를 지우지 않도록 최신 기록에서 시작
    _habits = _habits.where((h) => h.id != id).toList();
    for (final day in _logs.values) {
      day.remove(id);
    }
    await _persistHabits();
    await _persistLogs();
    notifyListeners();
  }

  /// 화면에 보이는 루틴들의 새 순서를 전체 목록에 반영한다.
  Future<void> reorderVisible(List<String> orderedIds) async {
    final slots = <int>[
      for (var i = 0; i < _habits.length; i++)
        if (orderedIds.contains(_habits[i].id)) i
    ];
    final byId = {for (final h in _habits) h.id: h};
    final next = List<Habit>.of(_habits);
    for (var k = 0; k < slots.length; k++) {
      next[slots[k]] = byId[orderedIds[k]]!;
    }
    _habits = next;
    await _persistHabits();
    notifyListeners();
  }

  // ---- 기록 ----
  /// 앱과 위젯(다른 isolate)이 같은 저장소를 쓰므로, 쓰기 직전에 디스크의 최신 기록을 다시 읽어
  /// 서로의 체크를 덮어쓰는 일을 막는다.
  Future<void> _refreshLogsAndRest() async {
    await _store.reload();
    _logs = _parseLogs(_store.readJson('logs'));
    final rest = _store.readJson('rest');
    _rest = rest is Map ? rest.keys.map((k) => '$k').toSet() : {};
  }

  Future<void> updateLog(String habitId, String date, HabitLog Function(HabitLog) edit) async {
    await _refreshLogsAndRest();
    // 최신 기록을 읽은 직후, 중간에 기다리는 일 없이 존재 확인과 수정을 한다.
    // 삭제된 루틴(예: 실행 중이던 타이머)의 기록은 만들지 않는다.
    if (habitById(habitId) == null) return;
    final day = _logs.putIfAbsent(date, () => {});
    final before = day[habitId];
    day[habitId] = edit(before ?? const HabitLog());
    try {
      await _persistLogs();
    } on Object {
      // 저장에 실패하면 메모리의 기록도 되돌려, 화면과 저장된 내용이 어긋나지 않게 한다
      if (before == null) {
        day.remove(habitId);
      } else {
        day[habitId] = before;
      }
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  }

  Future<void> setDone(String habitId, String date, bool done) =>
      updateLog(habitId, date, (l) => l.copyWith(done: done));

  /// 체크를 뒤집는다. 최신 기록을 읽은 뒤의 값을 기준으로 뒤집어, 위젯이 먼저 바꾼 상태를 거꾸로 되돌리지 않는다.
  Future<void> toggle(String habitId, String date) =>
      updateLog(habitId, date, (l) => l.copyWith(done: !l.done));

  // ---- 쉬는 날 ----
  Future<void> setRest(String date, bool rest) =>
      setRestRange(date, date, rest);

  /// 시작일부터 종료일까지 쉬는 날(휴가)로 표시하거나 해제한다.
  Future<void> setRestRange(String from, String to, bool rest) async {
    await _refreshLogsAndRest();
    for (var d = from; d.compareTo(to) <= 0; d = addDaysKey(d, 1)) {
      rest ? _rest.add(d) : _rest.remove(d);
    }
    await _persistRest();
    notifyListeners();
  }

  // ---- 모드 ----
  /// 모드를 바꾼다. [from]을 생략하면 오늘부터 적용되고, 지난 날의 모드는 이력에 그대로 남는다.
  Future<void> setActiveMode(String id, {String? from}) async {
    _activeMode = id;
    _modeFrom[from ?? todayKey()] = id;
    await _store.writeString('activeMode', id);
    await _store.writeJson('modeFrom', _modeFrom);
    notifyListeners();
  }

  Future<bool> addMode(String name) async {
    _modes = [..._modes, RoutineMode(id: newId(), name: name)];
    await _store.writeJson('modes', _modes.map((m) => m.toJson()).toList());
    notifyListeners();
    return true;
  }

  Future<void> renameMode(String id, String name) async {
    _modes = [for (final m in _modes) m.id == id ? RoutineMode(id: id, name: name) : m];
    await _store.writeJson('modes', _modes.map((m) => m.toJson()).toList());
    notifyListeners();
  }

  /// 모드를 지운다. [on]은 지운 날짜(생략하면 오늘).
  Future<void> deleteMode(String id, {String? on}) async {
    if (_modes.length <= 1) return;
    _modeDeletedOn[id] = on ?? todayKey();
    await _refreshLogsAndRest(); // _persistAll이 기록 전체를 다시 쓰므로 최신 기록에서 시작
    // 루틴의 모드 지정과 날짜별 모드 이력은 그대로 둔다. 지난 날의 달성률과 신호등이 바뀌지 않게 하려는 것이다.
    // 소속 모드가 모두 사라진 루틴은 지금부터 모든 모드에 나타난다(RoutineAnalyzer.inActiveMode).
    _modes = _modes.where((m) => m.id != id).toList();
    if (_activeMode == id) {
      _activeMode = _modes.first.id;
      _modeFrom[todayKey()] = _activeMode;
    }
    await _persistAll();
    notifyListeners();
  }

  // ---- 백업 ----
  Map<String, dynamic> exportJson() => {
        'habits': _habits.map((h) => h.toJson()).toList(),
        'modes': _modes.map((m) => m.toJson()).toList(),
        'activeMode': _activeMode,
        'modeFrom': _modeFrom,
        'modeDeleted': _modeDeletedOn,
        'logs': _logs.map((d, day) => MapEntry(d, day.map((id, l) => MapEntry(id, l.toJson())))),
        'rest': {for (final d in _rest) d: true},
      };

  /// 백업 JSON을 모두 해석해 본다. 형식이 틀리면 FormatException을 던지고 상태는 바꾸지 않는다.
  _Imported _parseImport(Map<String, dynamic> j) {
    try {
      final habits = ((j['habits'] as List?) ?? const [])
          .map((e) => Habit.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      var modes = ((j['modes'] as List?) ?? const [])
          .map((e) => RoutineMode.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      if (modes.isEmpty) modes = const [RoutineMode(id: 'm1', name: '기본')];
      var active = (j['activeMode'] as String?) ?? modes.first.id;
      if (!modes.any((m) => m.id == active)) active = modes.first.id;
      final rest = j['rest'];
      return _Imported(
        habits: habits,
        modes: modes,
        activeMode: active,
        modeFrom: _parseModeFrom(j['modeFrom'], active),
        modeDeleted: _parseStringMap(j['modeDeleted']),
        logs: _parseLogs(j['logs']),
        rest: rest is Map ? rest.keys.map((k) => '$k').toSet() : {},
      );
    } on TypeError catch (e) {
      throw FormatException('루틴 백업 형식이 올바르지 않아요: $e');
    } on FormatException {
      rethrow;
    }
  }

  /// 덮어쓰기 전에 형식만 검사한다.
  void validateJson(Map<String, dynamic> j) => _parseImport(j);

  /// 웹앱 또는 이 앱의 백업 JSON으로 덮어쓴다. 해석에 실패하면 기존 데이터는 그대로 둔다.
  Future<void> importJson(Map<String, dynamic> j) async {
    final d = _parseImport(j);
    _habits = d.habits;
    _modes = d.modes;
    _activeMode = d.activeMode;
    _modeFrom = d.modeFrom;
    _modeDeletedOn = d.modeDeleted;
    _logs = d.logs;
    _rest = d.rest;
    await _persistAll();
    notifyListeners();
  }

  Future<void> resetAll() async {
    _habits = _seedHabits();
    _modes = [const RoutineMode(id: 'm1', name: '기본')];
    _activeMode = 'm1';
    _modeFrom = {_modeEpoch: 'm1'};
    _modeDeletedOn = {};
    _logs = {};
    _rest = {};
    await _persistAll();
    notifyListeners();
  }
}
