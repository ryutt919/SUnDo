import 'package:flutter/foundation.dart';

import '../../domain/models/date_key.dart';
import '../../domain/models/journal_models.dart';
import '../services/calendar_service.dart';
import '../services/storage_service.dart';
import 'journal_repository.dart';

/// 투두와 기기 캘린더를 양방향으로 맞춰 두는 저장소.
///
/// 투두마다 만든(또는 가져온) 이벤트 ID와 마지막으로 맞춘 내용(서명 = 날짜와 제목)을 저장해 두고,
/// [sync]가 투두, 캘린더, 마지막 서명을 세 갈래로 비교한다.
///  - 투두만 바뀌었으면 캘린더 이벤트를 고친다.
///  - 캘린더만 바뀌었으면 투두를 고친다(제목, 날짜, 완료 표시, 이벤트 삭제 포함, [pullChanges]가 켜진 경우).
///  - 둘 다 바뀌었으면 투두가 이긴다.
/// 새 일정 가져오기([importNew])를 켜면 오늘부터 [importDays]일 안의 반복되지 않는 일정을 투두로 만든다.
/// 기기마다 다른 값이라 백업에는 넣지 않는다.
class CalendarRepository extends ChangeNotifier {
  CalendarRepository(this._store, this._service, this._journal);

  static const _key = 'calendar';
  static const importDays = 60;
  static const _doneMark = '✔ ';

  final StorageService _store;
  final CalendarService _service;
  final JournalRepository _journal;

  bool _enabled = false;
  bool _pullChanges = true;
  bool _importNew = false;
  String _calendarId = '';
  String _calendarName = '';
  Map<String, _Link> _links = {};
  Set<String> _ignored = {}; // 사용자가 투두를 지워서 다시 가져오지 않을 캘린더 일정
  Future<void> _running = Future.value();

  bool get enabled => _enabled;
  bool get pullChanges => _pullChanges;
  bool get importNew => _importNew;
  String get calendarId => _calendarId;
  String get calendarName => _calendarName;
  int get linkedCount => _links.length;

  Future<void> load() async {
    await _store.reload();
    final v = _store.readJson(_key);
    if (v is! Map) return;
    _enabled = v['enabled'] == true;
    _pullChanges = v['pullChanges'] != false;
    _importNew = v['importNew'] == true;
    _calendarId = (v['calendarId'] as String?) ?? '';
    _calendarName = (v['calendarName'] as String?) ?? '';
    final links = v['links'];
    _links = links is Map
        ? {
            for (final e in links.entries)
              if (e.value is Map) '${e.key}': _Link.fromJson((e.value as Map).cast<String, dynamic>())
          }
        : {};
    final ignored = v['ignored'];
    _ignored = ignored is List ? {for (final e in ignored) '$e'} : {};
    notifyListeners();
  }

  Future<void> _save() => _store.writeJson(_key, {
        'enabled': _enabled,
        'pullChanges': _pullChanges,
        'importNew': _importNew,
        'calendarId': _calendarId,
        'calendarName': _calendarName,
        'links': _links.map((k, v) => MapEntry(k, v.toJson())),
        'ignored': _ignored.toList(),
      });

  Future<bool> requestPermission() => _service.requestPermission();

  Future<List<CalendarChoice>> choices() async => [
        for (final c in await _service.writableCalendars())
          CalendarChoice(id: c.id, name: c.name, account: c.accountName ?? '', isPrimary: c.isPrimary)
      ];

  /// 연동 대상 캘린더를 정하고 켠다.
  Future<void> enable(CalendarChoice c) async {
    _enabled = true;
    _calendarId = c.id;
    _calendarName = c.name;
    await _save();
    notifyListeners();
  }

  /// 연동을 끈다. 이미 만든 이벤트는 캘린더에 그대로 남는다.
  Future<void> disable() async {
    _enabled = false;
    await _save();
    notifyListeners();
  }

  Future<void> setPullChanges(bool v) async {
    _pullChanges = v;
    await _save();
    notifyListeners();
  }

  Future<void> setImportNew(bool v) async {
    _importNew = v;
    await _save();
    notifyListeners();
  }

  /// 루티닝이 만든 캘린더 일정을 모두 지우고 연동 기록도 비운다. 가져온 일정은 원래 캘린더 것이라 지우지 않는다.
  Future<void> removeAllEvents() async {
    for (final l in _links.values) {
      if (l.imported) continue;
      try {
        await _service.delete(l.eventId);
      } on Exception catch (e) {
        debugPrint('캘린더 이벤트 삭제 실패: $e');
      }
    }
    _links = {};
    await _save();
    notifyListeners();
  }

  static String _title(Todo t) => t.done ? '$_doneMark${t.text}' : t.text;

  /// 이벤트 제목을 투두 내용으로 바꾼다. 제목 앞의 체크 표시는 완료 상태로 읽는다.
  static ({String text, bool done}) _parseTitle(String title) => title.startsWith(_doneMark)
      ? (text: title.substring(_doneMark.length).trim(), done: true)
      : (text: title.trim(), done: false);

  /// 투두와 캘린더를 맞춘다. 한 번에 하나씩만 실행하고, 항목 하나가 실패해도 나머지는 계속한다.
  Future<void> sync() {
    _running = _running.then((_) => _sync()).catchError((Object e) {
      debugPrint('캘린더 동기화 실패: $e');
    });
    return _running;
  }

  Future<void> _sync() async {
    if (!_enabled || _calendarId.isEmpty) return;
    if (!await _service.hasPermission()) return;
    var changed = false;
    final todos = _journal.todos;
    final alive = {for (final t in todos) t.id};

    // 1. 지워진 투두: 우리가 만든 일정은 캘린더에서도 지우고, 가져온 일정은 건드리지 않고 다시 가져오지 않게 기억한다.
    for (final id in _links.keys.toList()) {
      if (alive.contains(id)) continue;
      final link = _links[id]!;
      try {
        if (link.imported) {
          _ignored.add(link.eventId);
        } else {
          await _service.delete(link.eventId);
        }
        _links.remove(id);
        changed = true;
      } on Exception catch (e) {
        debugPrint('캘린더 이벤트 정리 실패: $e');
      }
    }

    // 2. 연결된 투두: 제목과 날짜를 필드별로 (투두, 캘린더, 마지막으로 맞춘 값) 세 갈래 비교
    for (final t in todos) {
      final link = _links[t.id];
      if (link == null) continue;
      try {
        if (link.calendarId != _calendarId) {
          // 대상 캘린더를 바꿨다. 우리가 만든 이벤트는 지우고 새 캘린더에 다시 만들며(3번), 가져온 것은 연결만 끊는다.
          if (!link.imported) await _service.delete(link.eventId);
          _links.remove(t.id);
          changed = true;
          continue;
        }
        final ev = await _service.get(link.eventId);
        if (ev == null) {
          // 캘린더에서 지운 일정은 투두도 지운다. 끄면 새 일정으로 다시 만든다(3번).
          if (_pullChanges) await _journal.deleteTodo(t.id);
          _links.remove(t.id);
          changed = true;
          continue;
        }
        if (await _mergeFields(t, ev, link)) changed = true;
      } on Exception catch (e) {
        debugPrint('캘린더 이벤트 갱신 실패(${t.text}): $e');
      }
    }

    // 3. 연결이 없는 투두는 새 일정으로 만든다(2번에서 지워진 투두가 있을 수 있어 최신 목록을 쓴다)
    for (final t in _journal.todos) {
      if (_links.containsKey(t.id)) continue;
      try {
        final id = await _service.create(calendarId: _calendarId, title: _title(t), day: parseDateKey(t.date));
        _links[t.id] = _Link(id, _calendarId, title: _title(t), date: t.date, imported: false);
        changed = true;
      } on Exception catch (e) {
        debugPrint('캘린더 이벤트 생성 실패(${t.text}): $e');
      }
    }

    // 4. 캘린더의 새 일정을 투두로 가져온다
    if (_importNew) {
      try {
        if (await _importFromCalendar()) changed = true;
      } on Exception catch (e) {
        debugPrint('캘린더 일정 가져오기 실패: $e');
      }
    }

    if (changed) {
      await _save();
      notifyListeners();
    }
  }

  /// 한 쌍(투두, 이벤트)을 필드별로 맞춘다. 바뀐 것이 있으면 true.
  ///  - 투두만 바뀐 필드는 캘린더로 보내고, 캘린더만 바뀐 필드는 투두로 가져온다(둘 다 바뀌면 투두가 이긴다).
  ///  - 가져온 일정과 시각이 있는 일정은 날짜를 옮기지 않으므로, 날짜는 캘린더 쪽 값만 따른다.
  Future<bool> _mergeFields(Todo t, CalendarEvent ev, _Link link) async {
    final dateIsPushable = !link.imported && ev.allDay;
    final todoTitle = _title(t);
    final evDate = dateKey(ev.day);

    final pushTitle = todoTitle != link.title;
    final pushDate = dateIsPushable && t.date != link.date;
    var newTitleBase = link.title;
    var newDateBase = link.date;
    var changed = false;

    if (pushTitle || pushDate) {
      final ok = await _service.update(
        eventId: link.eventId,
        title: pushTitle ? todoTitle : null,
        day: pushDate ? parseDateKey(t.date) : null,
      );
      if (!ok) {
        _links.remove(t.id); // 그 사이에 지워졌다. 다음 동기화 3번에서 새로 만든다.
        return true;
      }
      if (pushTitle) newTitleBase = todoTitle;
      if (pushDate) newDateBase = t.date;
      changed = true;
    }

    // 캘린더에서 바뀐 필드를 가져온다. 방금 투두에서 보낸 필드는 건너뛴다.
    final pullTitle = _pullChanges && !pushTitle && ev.title != link.title;
    final pullDate = _pullChanges && !pushDate && evDate != link.date && (!dateIsPushable || t.date == link.date);
    if (pullTitle || pullDate) {
      final parsed = _parseTitle(ev.title);
      await _journal.updateTodo(t.copyWith(
        text: pullTitle && parsed.text.isNotEmpty ? parsed.text : null,
        done: pullTitle && parsed.text.isNotEmpty ? parsed.done : null,
        date: pullDate ? evDate : null,
      ));
      if (pullTitle) newTitleBase = ev.title;
      if (pullDate) newDateBase = evDate;
      changed = true;
    }

    // 날짜를 보낼 수 없는 일정은 앱에서 날짜를 바꿔도 캘린더와 어긋난 채 두고, 캘린더 날짜를 기준으로 삼는다.
    if (!dateIsPushable && !pullDate) newDateBase = link.date;

    if (changed) _links[t.id] = _Link(link.eventId, link.calendarId, title: newTitleBase, date: newDateBase, imported: link.imported);
    return changed;
  }

  Future<bool> _importFromCalendar() async {
    final today = parseDateKey(todayKey());
    final events = await _service.listBetween(
      calendarId: _calendarId,
      from: today,
      to: DateTime(today.year, today.month, today.day + importDays),
    );
    final known = {for (final l in _links.values) l.eventId};
    var changed = false;
    for (final e in events) {
      if (e.recurring || e.title.trim().isEmpty) continue;
      if (known.contains(e.id) || _ignored.contains(e.id)) continue;
      final parsed = _parseTitle(e.title);
      if (parsed.text.isEmpty) continue;
      final todo = await _journal.addTodo(parsed.text, dateKey(e.day), done: parsed.done);
      _links[todo.id] = _Link(e.id, _calendarId, title: e.title, date: dateKey(e.day), imported: true);
      known.add(e.id);
      changed = true;
    }
    return changed;
  }
}

class CalendarChoice {
  const CalendarChoice({required this.id, required this.name, required this.account, required this.isPrimary});
  final String id;
  final String name;
  final String account;
  final bool isPrimary;
}

class _Link {
  const _Link(this.eventId, this.calendarId, {required this.title, required this.date, required this.imported});
  final String eventId;
  final String calendarId;

  /// 마지막으로 맞춘 제목과 날짜. 이후 어느 쪽이 바뀌었는지 가르는 기준이다.
  final String title;
  final String date;

  /// 캘린더에서 가져온 일정(원래 캘린더 소유). 지우거나 날짜를 옮기지 않는다.
  final bool imported;

  Map<String, dynamic> toJson() => {'event': eventId, 'calendar': calendarId, 'title': title, 'date': date, 'imported': imported};

  factory _Link.fromJson(Map<String, dynamic> j) => _Link(
        (j['event'] as String?) ?? '',
        (j['calendar'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        date: (j['date'] as String?) ?? '',
        imported: j['imported'] == true,
      );
}
