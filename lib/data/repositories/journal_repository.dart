import 'package:flutter/foundation.dart';

import '../../domain/models/id.dart';
import '../../domain/models/journal_models.dart';
import '../services/storage_service.dart';

/// 투두, 회고, 메모, 계획(목표)의 단일 출처.
class JournalRepository extends ChangeNotifier {
  JournalRepository(this._store);

  final StorageService _store;

  List<Todo> _todos = [];
  Map<String, DayReview> _reviews = {};
  List<Memo> _memos = [];
  List<Goal> _goals = [];

  /// 모든 투두(숨긴 것 포함). 통계와 캘린더 동기화가 쓴다.
  List<Todo> get todos => List.unmodifiable(_todos);

  /// "완료 숨기기"로 감추지 않은 투두. 투두 탭, 홈, 위젯이 쓴다.
  List<Todo> get visibleTodos =>
      List.unmodifiable(_todos.where((t) => !t.hidden));
  List<Memo> get memos => List.unmodifiable(_memos);
  List<Goal> get goals => List.unmodifiable(_goals);
  Map<String, DayReview> get reviews => Map.unmodifiable(_reviews);

  DayReview reviewOf(String date) => _reviews[date] ?? const DayReview();
  List<Memo> memosOf(String date) =>
      _memos.where((m) => m.date == date).toList();
  int get reviewDays => _reviews.values.where((r) => !r.isEmpty).length;

  Future<void> load() async {
    await _store.reload();
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) {
      final v = _store.readJson(key);
      return v is List
          ? v.map((e) => f((e as Map).cast<String, dynamic>())).toList()
          : <T>[];
    }

    _todos = list('todos', Todo.fromJson);
    _memos = list('memos', Memo.fromJson);
    _goals = list('goals', Goal.fromJson);
    final r = _store.readJson('reviews');
    _reviews = r is Map
        ? r.map(
            (k, v) => MapEntry(
              '$k',
              DayReview.fromJson((v as Map).cast<String, dynamic>()),
            ),
          )
        : {};
    notifyListeners();
  }

  Future<void> _save(String key) {
    switch (key) {
      case 'todos':
        return _store.writeJson(key, _todos.map((e) => e.toJson()).toList());
      case 'memos':
        return _store.writeJson(key, _memos.map((e) => e.toJson()).toList());
      case 'goals':
        return _store.writeJson(key, _goals.map((e) => e.toJson()).toList());
      case 'reviews':
        return _store.writeJson(
          key,
          _reviews.map((k, v) => MapEntry(k, v.toJson())),
        );
    }
    throw ArgumentError('알 수 없는 저장 키: $key');
  }

  // ---- 투두 ----
  /// 투두를 바꾸기 직전에 디스크의 최신 목록을 읽는다. 위젯(다른 isolate)이 방금 바꾼 투두를
  /// 앱의 오래된 목록으로 덮어쓰거나, 앱에서 지운 투두를 되살리지 않기 위해서다.
  Future<void> _refreshTodos() async {
    await _store.reload();
    final v = _store.readJson('todos');
    _todos = v is List
        ? v
              .map((e) => Todo.fromJson((e as Map).cast<String, dynamic>()))
              .toList()
        : <Todo>[];
  }

  Future<Todo> addTodo(
    String text,
    String date, {
    bool done = false,
    String time = '',
  }) async {
    await _refreshTodos();
    final todo = Todo(
      id: newId(),
      text: text,
      date: date,
      done: done,
      time: time,
    );
    _todos = [..._todos, todo];
    await _save('todos');
    notifyListeners();
    return todo;
  }

  Future<void> updateTodo(Todo t) async {
    await _refreshTodos();
    _todos = [for (final x in _todos) x.id == t.id ? t : x];
    await _save('todos');
    notifyListeners();
  }

  /// 최신 투두의 지정한 필드만 바꾼다. 삭제된 투두는 되살리지 않는다.
  /// [expected]가 있으면 기다리는 동안 바뀐 필드는 유지하고, 날짜와 시간은 함께 비교한다.
  Future<Todo?> patchTodo(
    String id, {
    String? text,
    bool? done,
    String? date,
    String? time,
    Todo? expected,
  }) async {
    await _refreshTodos();
    final latest = _todos.where((t) => t.id == id).firstOrNull;
    if (latest == null) return null;
    final scheduleMatches =
        expected == null ||
        (latest.date == expected.date && latest.time == expected.time);
    final patched = latest.copyWith(
      text: expected == null || latest.text == expected.text ? text : null,
      done: expected == null || latest.done == expected.done ? done : null,
      date: scheduleMatches ? date : null,
      time: scheduleMatches ? time : null,
    );
    final previous = _todos;
    _todos = [for (final t in _todos) t.id == id ? patched : t];
    try {
      await _save('todos');
    } on Exception {
      _todos = previous;
      rethrow;
    }
    notifyListeners();
    return patched;
  }

  /// 여러 투두를 한 번에 지운다(저장은 한 번).
  Future<void> deleteTodos(Set<String> ids) async {
    if (ids.isEmpty) return;
    await _refreshTodos();
    _todos = _todos.where((t) => !ids.contains(t.id)).toList();
    await _save('todos');
    notifyListeners();
  }

  /// 투두를 지우지 않고 목록에서만 감춘다(통계에는 남는다). 저장은 한 번.
  Future<void> hideTodos(Set<String> ids) async {
    if (ids.isEmpty) return;
    await _refreshTodos();
    _todos = [
      for (final t in _todos) ids.contains(t.id) ? t.copyWith(hidden: true) : t,
    ];
    await _save('todos');
    notifyListeners();
  }

  Future<void> deleteTodo(String id) async {
    await _refreshTodos();
    _todos = _todos.where((t) => t.id != id).toList();
    await _save('todos');
    notifyListeners();
  }

  /// 외부 삭제를 기다리는 동안 앱이나 위젯에서 수정한 투두는 유지한다.
  Future<bool> deleteTodoIfUnchanged(String id, Todo expected) async {
    await _refreshTodos();
    final latest = _todos.where((t) => t.id == id).firstOrNull;
    if (latest == null ||
        latest.text != expected.text ||
        latest.date != expected.date ||
        latest.time != expected.time ||
        latest.done != expected.done ||
        latest.hidden != expected.hidden) {
      return false;
    }
    final previous = _todos;
    _todos = _todos.where((t) => t.id != id).toList();
    try {
      await _save('todos');
    } on Exception {
      _todos = previous;
      rethrow;
    }
    notifyListeners();
    return true;
  }

  // ---- 회고 ----
  Future<void> saveReview(String date, DayReview r) async {
    _reviews = {..._reviews, date: r};
    await _save('reviews');
    notifyListeners();
  }

  // ---- 메모 ----
  Future<void> saveMemo(Memo m) async {
    final exists = _memos.any((x) => x.id == m.id);
    _memos = exists
        ? [for (final x in _memos) x.id == m.id ? m : x]
        : [..._memos, m];
    await _save('memos');
    notifyListeners();
  }

  Future<void> deleteMemo(String id) async {
    _memos = _memos.where((m) => m.id != id).toList();
    await _save('memos');
    notifyListeners();
  }

  // ---- 계획(목표) ----
  List<Goal> goalsFor(GoalPeriod p, String key) =>
      _goals.where((g) => g.period == p && g.periodKey == key).toList();

  Future<void> saveGoal(Goal g) async {
    final exists = _goals.any((x) => x.id == g.id);
    _goals = exists
        ? [for (final x in _goals) x.id == g.id ? g : x]
        : [..._goals, g];
    await _save('goals');
    notifyListeners();
  }

  Future<void> deleteGoal(String id) async {
    _goals = _goals.where((g) => g.id != id).toList();
    await _save('goals');
    notifyListeners();
  }

  // ---- 백업 ----
  Map<String, dynamic> exportJson() => {
    'todos': _todos.map((e) => e.toJson()).toList(),
    'memos': _memos.map((e) => e.toJson()).toList(),
    'goals': _goals.map((e) => e.toJson()).toList(),
    'reviews': _reviews.map((k, v) => MapEntry(k, v.toJson())),
  };

  /// 백업 JSON을 모두 해석해 본다. 형식이 틀리면 FormatException을 던지고 상태는 바꾸지 않는다.
  ({
    List<Todo> todos,
    List<Memo> memos,
    List<Goal> goals,
    Map<String, DayReview> reviews,
  })
  _parseImport(Map<String, dynamic> j) {
    try {
      List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
          ((j[key] as List?) ?? const [])
              .map((e) => f((e as Map).cast<String, dynamic>()))
              .toList();
      final r = j['reviews'];
      return (
        todos: list('todos', Todo.fromJson),
        memos: list('memos', Memo.fromJson),
        goals: list('goals', Goal.fromJson),
        reviews: r is Map
            ? r.map(
                (k, v) => MapEntry(
                  '$k',
                  DayReview.fromJson((v as Map).cast<String, dynamic>()),
                ),
              )
            : <String, DayReview>{},
      );
    } on TypeError catch (e) {
      throw FormatException('회고/투두 백업 형식이 올바르지 않아요: $e');
    }
  }

  /// 덮어쓰기 전에 형식만 검사한다.
  void validateJson(Map<String, dynamic> j) => _parseImport(j);

  Future<void> importJson(Map<String, dynamic> j) async {
    final d = _parseImport(j);
    _todos = d.todos;
    _memos = d.memos;
    _goals = d.goals;
    _reviews = d.reviews;
    for (final k in ['todos', 'memos', 'goals', 'reviews']) {
      await _save(k);
    }
    notifyListeners();
  }

  Future<void> resetAll() => importJson({});
}
