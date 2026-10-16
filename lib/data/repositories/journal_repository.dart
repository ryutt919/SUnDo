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

  List<Todo> get todos => List.unmodifiable(_todos);
  List<Memo> get memos => List.unmodifiable(_memos);
  List<Goal> get goals => List.unmodifiable(_goals);
  Map<String, DayReview> get reviews => Map.unmodifiable(_reviews);

  DayReview reviewOf(String date) => _reviews[date] ?? const DayReview();
  List<Memo> memosOf(String date) => _memos.where((m) => m.date == date).toList();
  int get reviewDays => _reviews.values.where((r) => !r.isEmpty).length;

  Future<void> load() async {
    await _store.reload();
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) {
      final v = _store.readJson(key);
      return v is List ? v.map((e) => f((e as Map).cast<String, dynamic>())).toList() : <T>[];
    }

    _todos = list('todos', Todo.fromJson);
    _memos = list('memos', Memo.fromJson);
    _goals = list('goals', Goal.fromJson);
    final r = _store.readJson('reviews');
    _reviews = r is Map
        ? r.map((k, v) => MapEntry('$k', DayReview.fromJson((v as Map).cast<String, dynamic>())))
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
        return _store.writeJson(key, _reviews.map((k, v) => MapEntry(k, v.toJson())));
    }
    throw ArgumentError('알 수 없는 저장 키: $key');
  }

  // ---- 투두 ----
  Future<void> addTodo(String text, String date) async {
    _todos = [..._todos, Todo(id: newId(), text: text, date: date)];
    await _save('todos');
    notifyListeners();
  }

  Future<void> updateTodo(Todo t) async {
    _todos = [for (final x in _todos) x.id == t.id ? t : x];
    await _save('todos');
    notifyListeners();
  }

  Future<void> deleteTodo(String id) async {
    _todos = _todos.where((t) => t.id != id).toList();
    await _save('todos');
    notifyListeners();
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
    _memos = exists ? [for (final x in _memos) x.id == m.id ? m : x] : [..._memos, m];
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
    _goals = exists ? [for (final x in _goals) x.id == g.id ? g : x] : [..._goals, g];
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

  Future<void> importJson(Map<String, dynamic> j) async {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((j[key] as List?) ?? const []).map((e) => f((e as Map).cast<String, dynamic>())).toList();
    _todos = list('todos', Todo.fromJson);
    _memos = list('memos', Memo.fromJson);
    _goals = list('goals', Goal.fromJson);
    final r = j['reviews'];
    _reviews = r is Map
        ? r.map((k, v) => MapEntry('$k', DayReview.fromJson((v as Map).cast<String, dynamic>())))
        : {};
    for (final k in ['todos', 'memos', 'goals', 'reviews']) {
      await _save(k);
    }
    notifyListeners();
  }

  Future<void> resetAll() => importJson({});
}
