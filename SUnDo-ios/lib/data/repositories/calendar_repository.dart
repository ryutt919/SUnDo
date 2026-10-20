import 'package:flutter/foundation.dart';

import '../../domain/models/date_key.dart';
import '../../domain/models/journal_models.dart';
import '../services/calendar_service.dart';
import '../services/storage_service.dart';
import 'journal_repository.dart';

enum CalendarSyncStatus {
  success,
  partialFailure,
  permissionDenied,
  disabled,
  failure,
}

class CalendarSyncException implements Exception {
  const CalendarSyncException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CalendarSyncResult {
  const CalendarSyncResult({
    required this.status,
    required this.processedCount,
    required this.failedCount,
    required this.completedAt,
    this.detail,
  });
  final CalendarSyncStatus status;
  final int processedCount;
  final int failedCount;
  final DateTime completedAt;
  final String? detail;
}

/// 투두와 기기 캘린더를 양방향으로 맞춰 두는 저장소.
///
/// 투두마다 만든(또는 가져온) 이벤트 ID와 마지막으로 맞춘 제목과 일정(날짜와 시각)을 저장해 두고,
/// [sync]가 투두, 캘린더, 마지막 서명을 세 갈래로 비교한다.
///  - 투두만 바뀌었으면 캘린더 이벤트를 고친다.
///  - 캘린더만 바뀌었으면 투두를 고친다(제목, 날짜, 시각, 완료 표시, 이벤트 삭제 포함, [pullChanges]가 켜진 경우).
///  - 둘 다 바뀌었으면 투두가 이긴다.
/// 새 일정 가져오기([importNew], 기본으로 켜짐)가 켜져 있으면 오늘부터 [importDays]일 안의 반복되지 않는 일정을
/// 시각까지 포함해 투두로 만든다.
/// 기기마다 다른 값이라 백업에는 넣지 않는다.
class CalendarRepository extends ChangeNotifier {
  CalendarRepository(this._store, this._service, this._journal);

  static const _key = 'calendar';
  static const _schema = 2; // 2: 새 일정 가져오기를 기본으로 켬
  static const importDays = 60;
  static const _doneMark = '✔ ';

  final StorageService _store;
  final CalendarService _service;
  final JournalRepository _journal;

  bool _enabled = false;
  bool _pullChanges = true;
  bool _importNew = true; // 새로 연동하면 캘린더 일정이 자동으로 투두에 들어온다
  String _calendarId = '';
  String _calendarName = '';
  Map<String, _Link> _links = {};
  Set<String> _ignored = {}; // 사용자가 투두를 지워서 다시 가져오지 않을 캘린더 일정
  Set<String>? _importIds; // 새 일정을 가져올 캘린더. null이면 기본값(쓰기 가능한 모든 캘린더)
  Future<void> _running = Future.value();

  CalendarSyncResult? _lastResult;
  DateTime? _lastSuccessAt;
  bool _isSyncing = false;
  Set<String> _readOnlyIds = {};
  Set<String> _knownCalendarIds = {};
  CalendarSyncResult? get lastResult => _lastResult;
  DateTime? get lastSuccessAt => _lastSuccessAt;
  bool get isSyncing => _isSyncing;
  bool isTodoScheduleReadOnly(String todoId) {
    final link = _links[todoId];
    return _enabled &&
        link != null &&
        (_readOnlyIds.contains(link.calendarId) ||
            !_knownCalendarIds.contains(link.calendarId));
  }

  bool get enabled => _enabled;
  bool get pullChanges => _pullChanges;
  bool get importNew => _importNew;
  String get calendarId => _calendarId;
  String get calendarName => _calendarName;
  int get linkedCount => _links.length;

  /// 직접 고른 가져올 캘린더. null이면 기본값(쓰기 가능한 모든 캘린더, 공휴일 같은 읽기 전용은 제외).
  Set<String>? get importCalendarIds =>
      _importIds == null ? null : Set.unmodifiable(_importIds!);

  Future<void> load() async {
    await _store.reload();
    final v = _store.readJson(_key);
    if (v is! Map) return;
    _enabled = v['enabled'] == true;
    _pullChanges = v['pullChanges'] != false;
    // 예전에는 꺼진 채로 시작했다. 2판으로 올라올 때 한 번만 켜서, 캘린더 일정이 자동으로 투두에 들어오게 한다.
    final migrate = ((v['schema'] as num?)?.toInt() ?? 1) < _schema;
    _importNew = migrate || v['importNew'] != false;
    _calendarId = (v['calendarId'] as String?) ?? '';
    _calendarName = (v['calendarName'] as String?) ?? '';
    _lastSuccessAt = DateTime.tryParse('${v['lastSuccessAt'] ?? ''}');
    final result = v['lastResult'];
    if (result is Map) {
      final completedAt = DateTime.tryParse('${result['completedAt'] ?? ''}');
      final status = CalendarSyncStatus.values
          .where((s) => s.name == result['status'])
          .firstOrNull;
      if (completedAt != null && status != null) {
        _lastResult = CalendarSyncResult(
          status: status,
          processedCount: (result['processedCount'] as num?)?.toInt() ?? 0,
          failedCount: (result['failedCount'] as num?)?.toInt() ?? 0,
          completedAt: completedAt,
          detail: result['detail'] as String?,
        );
      }
    }
    final links = v['links'];
    _links = links is Map
        ? {
            for (final e in links.entries)
              if (e.value is Map)
                '${e.key}': _Link.fromJson(
                  (e.value as Map).cast<String, dynamic>(),
                ),
          }
        : {};
    final ignored = v['ignored'];
    _ignored = ignored is List ? {for (final e in ignored) '$e'} : {};
    final ids = v['importIds'];
    _importIds = ids is List ? {for (final e in ids) '$e'} : null;
    notifyListeners();
  }

  Future<void> _save() => _store.writeJson(_key, {
    'enabled': _enabled,
    if (_lastSuccessAt != null)
      'lastSuccessAt': _lastSuccessAt!.toIso8601String(),
    if (_lastResult != null)
      'lastResult': {
        'status': _lastResult!.status.name,
        'processedCount': _lastResult!.processedCount,
        'failedCount': _lastResult!.failedCount,
        'completedAt': _lastResult!.completedAt.toIso8601String(),
        if (_lastResult!.detail != null) 'detail': _lastResult!.detail,
      },
    'pullChanges': _pullChanges,
    'schema': _schema,
    'importNew': _importNew,
    'calendarId': _calendarId,
    'calendarName': _calendarName,
    'links': _links.map((k, v) => MapEntry(k, v.toJson())),
    'ignored': _ignored.toList(),
    if (_importIds != null) 'importIds': _importIds!.toList(),
  });

  Future<bool> requestPermission() => _service.requestPermission();

  Future<List<CalendarChoice>> choices() async => [
    for (final c in await _service.writableCalendars())
      CalendarChoice(
        id: c.id,
        name: c.name,
        account: c.accountName ?? '',
        isPrimary: c.isPrimary,
      ),
  ];

  /// 가져올 캘린더를 고르는 화면에 보일 목록(숨기지 않은 모든 캘린더).
  Future<List<CalendarChoice>> importChoices() async => [
    for (final c in await _service.visibleCalendars())
      CalendarChoice(
        id: c.id,
        name: c.name,
        account: c.accountName ?? '',
        isPrimary: c.isPrimary,
        readOnly: c.readOnly,
      ),
  ];

  /// 가져올 캘린더를 정한다. null이면 기본값(쓰기 가능한 모든 캘린더)으로 돌아간다.
  Future<void> setImportCalendars(Set<String>? ids) async {
    _importIds = ids == null ? null : {...ids};
    await _save();
    notifyListeners();
  }

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
    if (!await _service.hasPermission()) {
      throw CalendarSyncException('캘린더 권한이 필요함');
    }
    final calendars = await _service.visibleCalendars();
    _knownCalendarIds = {for (final c in calendars) c.id};
    _readOnlyIds = {
      for (final c in calendars)
        if (c.readOnly) c.id,
    };
    var failures = 0;
    for (final entry in _links.entries.toList()) {
      try {
        if (!entry.value.imported) {
          _requireWritable(entry.value.calendarId);
          await _service.delete(entry.value.eventId);
        }
        _links.remove(entry.key);
      } on Exception catch (e) {
        failures++;
        debugPrint('캘린더 삭제 실패: ${e.runtimeType}');
      }
    }
    await _save();
    notifyListeners();
    if (failures > 0) {
      throw CalendarSyncException('일부 캘린더 일정을 삭제하지 못함: $failures');
    }
  }

  static String _title(Todo t) => t.done ? '$_doneMark${t.text}' : t.text;

  /// 이벤트 제목을 투두 내용으로 바꾼다. 제목 앞의 체크 표시는 완료 상태로 읽는다.
  static ({String text, bool done}) _parseTitle(String title) =>
      title.startsWith(_doneMark)
      ? (text: title.substring(_doneMark.length).trim(), done: true)
      : (text: title.trim(), done: false);

  /// 투두와 캘린더를 맞춘다. 한 번에 하나씩만 실행하고, 항목 하나가 실패해도 나머지는 계속한다.
  Future<CalendarSyncResult> sync() {
    final next = _running.then((_) => _runSync());
    _running = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        debugPrint('캘린더 실행 오류: ${error.runtimeType}');
      },
    );
    return next;
  }

  CalendarSyncResult _result(
    CalendarSyncStatus status,
    int processed,
    int failed, {
    String? detail,
  }) {
    final result = CalendarSyncResult(
      status: status,
      processedCount: processed,
      failedCount: failed,
      completedAt: DateTime.now(),
      detail: detail,
    );
    _lastResult = result;
    if (status == CalendarSyncStatus.success) {
      _lastSuccessAt = result.completedAt;
    }
    return result;
  }

  Todo? _todo(String id) => _journal.todos.where((t) => t.id == id).firstOrNull;
  static bool _sameTodo(Todo a, Todo b) =>
      a.text == b.text &&
      a.done == b.done &&
      a.date == b.date &&
      a.time == b.time &&
      a.hidden == b.hidden;
  bool _writable(String id) =>
      _knownCalendarIds.contains(id) && !_readOnlyIds.contains(id);
  void _requireWritable(String id) {
    if (!_writable(id)) {
      throw CalendarSyncException(
        '읽기 전용이거나 사용할 수 없는 캘린더예요. 캘린더의 쓰기 권한을 확인하거나 쓰기 가능한 캘린더를 선택해 주세요.',
      );
    }
  }

  Future<CalendarSyncResult> _runSync() async {
    _isSyncing = true;
    notifyListeners();
    final previousSuccessAt = _lastSuccessAt;
    try {
      final result = await _performSync();
      try {
        await _save();
        return result;
      } on Exception catch (e) {
        _lastSuccessAt = previousSuccessAt;
        debugPrint('캘린더 결과 저장 실패: ${e.runtimeType}');
        return _result(
          CalendarSyncStatus.failure,
          result.processedCount,
          result.failedCount + 1,
          detail: '동기화 결과를 저장하지 못했어요.',
        );
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<CalendarSyncResult> _performSync() async {
    var processed = 0;
    var failed = 0;
    String? failureDetail;
    try {
      if (!_enabled || _calendarId.isEmpty) {
        return _result(CalendarSyncStatus.disabled, 0, 0);
      }
      if (!await _service.hasPermission()) {
        return _result(CalendarSyncStatus.permissionDenied, 0, 0);
      }
      final calendars = await _service.visibleCalendars();
      _knownCalendarIds = {for (final c in calendars) c.id};
      _readOnlyIds = {
        for (final c in calendars)
          if (c.readOnly) c.id,
      };
      for (final id in _links.keys.toList()) {
        if (_todo(id) != null) continue;
        final link = _links[id]!;
        try {
          if (link.imported) {
            _ignored.add(link.eventId);
          } else {
            _requireWritable(link.calendarId);
            await _service.delete(link.eventId);
          }
          _links.remove(id);
          processed++;
        } on Exception catch (e) {
          failed++;
          if (e is CalendarSyncException) failureDetail ??= e.message;
          debugPrint('캘린더 정리 실패: ${e.runtimeType}');
        }
      }
      for (final snapshot in _journal.todos) {
        final link = _links[snapshot.id];
        if (link == null) continue;
        try {
          if (link.calendarId != _calendarId && !link.imported) {
            _requireWritable(link.calendarId);
            await _service.delete(link.eventId);
            _links.remove(snapshot.id);
            processed++;
            continue;
          }
          final ev = await _service.get(link.eventId);
          final latest = _todo(snapshot.id);
          if (latest == null) continue;
          if (ev == null) {
            // 기기 읽기를 기다리는 동안 수정한 투두는 삭제하지 않는다.
            if (_pullChanges &&
                _sameTodo(snapshot, latest) &&
                _title(latest) == link.title &&
                latest.date == link.date &&
                latest.time == link.time) {
              await _journal.deleteTodoIfUnchanged(snapshot.id, snapshot);
            }
            _links.remove(snapshot.id);
            processed++;
            continue;
          }
          if (await _mergeFields(latest, ev, link)) processed++;
        } on Exception catch (e) {
          failed++;
          if (e is CalendarSyncException) failureDetail ??= e.message;
          debugPrint('캘린더 갱신 실패: ${e.runtimeType}');
        }
      }
      for (final snapshot in _journal.todos) {
        if (_links.containsKey(snapshot.id)) continue;
        final t = _todo(snapshot.id);
        if (t == null) continue;
        try {
          _requireWritable(_calendarId);
          final id = await _service.create(
            calendarId: _calendarId,
            title: _title(t),
            day: parseDateKey(t.date),
            time: t.time,
          );
          // 생성 대기 중 삭제되어도 연결을 남겨 다음 실행에서 고아 일정을 정리한다.
          _links[t.id] = _Link(
            id,
            _calendarId,
            title: _title(t),
            date: t.date,
            imported: false,
            time: t.time,
            scheduleKnown: true,
          );
          processed++;
        } on Exception catch (e) {
          failed++;
          if (e is CalendarSyncException) failureDetail ??= e.message;
          debugPrint('캘린더 생성 실패: ${e.runtimeType}');
        }
      }
      if (_importNew) {
        try {
          final imported = await _importFromCalendar();
          processed += imported.processed;
          failed += imported.failed;
        } on Exception catch (e) {
          failed++;
          if (e is CalendarSyncException) failureDetail ??= e.message;
          debugPrint('캘린더 가져오기 실패: ${e.runtimeType}');
        }
      }
      await _save();
      return _result(
        failed == 0
            ? CalendarSyncStatus.success
            : processed > 0
            ? CalendarSyncStatus.partialFailure
            : CalendarSyncStatus.failure,
        processed,
        failed,
        detail: failed == 0
            ? null
            : failureDetail ??
                  '일부 일정을 반영하지 못했어요. 캘린더의 쓰기 권한을 확인한 뒤 다시 시도해 주세요.',
      );
    } on Exception catch (e) {
      debugPrint('캘린더 동기화 실패: ${e.runtimeType}');
      return _result(
        CalendarSyncStatus.failure,
        processed,
        failed + 1,
        detail: '캘린더를 읽거나 저장하지 못했어요. 다시 시도해 주세요.',
      );
    }
  }

  Future<bool> _mergeFields(Todo t, CalendarEvent ev, _Link link) async {
    final todoTitle = _title(t);
    final remoteTime = ev.allDay ? '' : ev.time;
    final remoteDate = dateKey(ev.day);
    final appScheduleChanged = t.date != link.date || t.time != link.time;
    final remoteScheduleChanged =
        remoteDate != link.date || remoteTime != link.time;
    final legacy = !link.scheduleKnown && !link.imported && t.time.isNotEmpty;
    // 옛 앱이 종일로 생성한 링크만 같은 ID로 보정한다. 외부에서도 일정을 바꿨으면 추정해서 덮지 않는다.
    if (legacy &&
        remoteScheduleChanged &&
        (t.date != remoteDate || t.time != remoteTime)) {
      throw CalendarSyncException(
        '기존 연결의 날짜와 시간이 충돌해요. 투두와 캘린더 일정의 날짜와 시간을 확인하고 같은 값으로 맞춰 주세요.',
      );
    }
    final pushTitle = todoTitle != link.title;
    final pushSchedule =
        appScheduleChanged &&
        !(legacy && t.date == remoteDate && t.time == remoteTime);
    final pullTitle = _pullChanges && !pushTitle && ev.title != link.title;
    final pullSchedule =
        _pullChanges && !appScheduleChanged && remoteScheduleChanged;
    var titleBase = link.title;
    var dateBase = link.date;
    var timeBase = link.time;
    var changed = false;
    if (pushTitle || pushSchedule) {
      _requireWritable(link.calendarId);
      final ok = await _service.update(
        eventId: link.eventId,
        title: pushTitle ? todoTitle : null,
        day: pushSchedule ? parseDateKey(t.date) : null,
        time: pushSchedule ? t.time : null,
      );
      if (!ok) throw CalendarSyncException('수정할 일정이 사라짐');
      if (pushTitle) titleBase = todoTitle;
      if (pushSchedule) {
        dateBase = t.date;
        timeBase = t.time;
      }
      changed = true;
    }
    if (pullTitle || pullSchedule) {
      final latest = _todo(t.id);
      if (latest != null) {
        final parsed = _parseTitle(ev.title);
        final acceptTitle =
            pullTitle && _title(latest) == todoTitle && parsed.text.isNotEmpty;
        final acceptSchedule =
            pullSchedule && latest.date == t.date && latest.time == t.time;
        if (acceptTitle || acceptSchedule) {
          final applied = await _journal.patchTodo(
            t.id,
            expected: latest,
            text: acceptTitle ? parsed.text : null,
            done: acceptTitle ? parsed.done : null,
            date: acceptSchedule ? remoteDate : null,
            time: acceptSchedule ? remoteTime : null,
          );
          if (applied != null && acceptTitle && _title(applied) == ev.title) {
            titleBase = ev.title;
          }
          if (applied != null &&
              acceptSchedule &&
              applied.date == remoteDate &&
              applied.time == remoteTime) {
            dateBase = remoteDate;
            timeBase = remoteTime;
          }
          changed = true;
        }
      }
    }
    if (legacy && t.date == remoteDate && t.time == remoteTime) {
      dateBase = remoteDate;
      timeBase = remoteTime;
      changed = true;
    }
    if (changed || !link.scheduleKnown) {
      _links[t.id] = _Link(
        link.eventId,
        link.calendarId,
        title: titleBase,
        date: dateBase,
        imported: link.imported,
        time: timeBase,
        scheduleKnown: true,
      );
    }
    return changed;
  }

  /// 가져올 캘린더 ID들. 직접 고른 것이 없으면 쓰기 가능한 모든 캘린더. 연동 캘린더는 항상 포함한다.
  Future<List<String>> _importCalendarIds() async {
    final ids =
        _importIds ??
        {for (final c in await _service.writableCalendars()) c.id};
    return {...ids, _calendarId}.toList();
  }

  Future<({int processed, int failed})> _importFromCalendar() async {
    final today = parseDateKey(todayKey());
    final events = await _service.listBetween(
      calendarIds: await _importCalendarIds(),
      from: today,
      to: DateTime(today.year, today.month, today.day + importDays),
    );
    final known = {for (final l in _links.values) l.eventId};
    var imported = 0;
    var failed = 0;
    for (final e in events) {
      if (e.recurring || e.title.trim().isEmpty) continue;
      if (known.contains(e.id) || _ignored.contains(e.id)) continue;
      final parsed = _parseTitle(e.title);
      if (parsed.text.isEmpty) continue;
      try {
        final todo = await _journal.addTodo(
          parsed.text,
          dateKey(e.day),
          done: parsed.done,
          time: e.time,
        );
        _links[todo.id] = _Link(
          e.id,
          e.calendarId.isEmpty ? _calendarId : e.calendarId,
          title: e.title,
          date: dateKey(e.day),
          imported: true,
          time: e.time,
          scheduleKnown: true,
        );
        known.add(e.id);
        imported++;
      } on Exception catch (e) {
        failed++;
        debugPrint('캘린더 항목 가져오기 실패: ${e.runtimeType}');
      }
    }
    return (processed: imported, failed: failed);
  }
}

class CalendarChoice {
  const CalendarChoice({
    required this.id,
    required this.name,
    required this.account,
    required this.isPrimary,
    this.readOnly = false,
  });
  final String id;
  final String name;
  final String account;
  final bool isPrimary;
  final bool readOnly; // 공휴일 같은 읽기 전용 캘린더
}

class _Link {
  const _Link(
    this.eventId,
    this.calendarId, {
    required this.title,
    required this.date,
    required this.imported,
    this.time = '',
    this.scheduleKnown = false,
  });
  final String eventId;
  final String calendarId;

  /// 마지막으로 맞춘 제목과 날짜. 이후 어느 쪽이 바뀌었는지 가르는 기준이다.
  final String title;
  final String date;

  /// 캘린더에서 가져온 일정은 투두를 지워도 외부에서 삭제하지 않는다.
  final bool imported;

  /// 마지막으로 맞춘 시각, 빈 문자열은 종일 일정이다.
  final String time;
  final bool scheduleKnown;

  Map<String, dynamic> toJson() => {
    'event': eventId,
    'calendar': calendarId,
    'title': title,
    'date': date,
    'imported': imported,
    'time': time,
    'scheduleKnown': scheduleKnown,
  };

  factory _Link.fromJson(Map<String, dynamic> j) => _Link(
    (j['event'] as String?) ?? '',
    (j['calendar'] as String?) ?? '',
    title: (j['title'] as String?) ?? '',
    date: (j['date'] as String?) ?? '',
    imported: j['imported'] == true,
    time: (j['time'] as String?) ?? '',
    scheduleKnown: j['scheduleKnown'] == true,
  );
}
