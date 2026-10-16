import 'package:flutter/foundation.dart';

import '../../domain/models/date_key.dart';
import '../../domain/models/journal_models.dart';
import '../services/calendar_service.dart';
import '../services/storage_service.dart';

/// 투두를 기기 캘린더에 맞춰 두는 저장소. 앱에서 캘린더로 한 방향만 동기화한다.
///
/// 투두마다 만든 이벤트 ID와 마지막으로 맞춘 내용(서명)을 저장해 두고, [sync]가 현재 투두와 비교해
/// 새로 만들고, 바뀐 것만 고치고, 사라진 투두의 이벤트는 지운다. 위젯에서 체크한 변화도 앱이 열릴 때
/// 같은 방식으로 따라잡는다. 기기마다 다른 값이라 백업에는 넣지 않는다.
class CalendarRepository extends ChangeNotifier {
  CalendarRepository(this._store, this._service);

  static const _key = 'calendar';

  final StorageService _store;
  final CalendarService _service;

  bool _enabled = false;
  String _calendarId = '';
  String _calendarName = '';
  Map<String, _Link> _links = {};

  bool get enabled => _enabled;
  String get calendarId => _calendarId;
  String get calendarName => _calendarName;
  int get linkedCount => _links.length;

  Future<void> load() async {
    await _store.reload();
    final v = _store.readJson(_key);
    if (v is! Map) return;
    _enabled = v['enabled'] == true;
    _calendarId = (v['calendarId'] as String?) ?? '';
    _calendarName = (v['calendarName'] as String?) ?? '';
    final links = v['links'];
    _links = links is Map
        ? {
            for (final e in links.entries)
              if (e.value is Map) '${e.key}': _Link.fromJson((e.value as Map).cast<String, dynamic>())
          }
        : {};
    notifyListeners();
  }

  Future<void> _save() => _store.writeJson(_key, {
        'enabled': _enabled,
        'calendarId': _calendarId,
        'calendarName': _calendarName,
        'links': _links.map((k, v) => MapEntry(k, v.toJson())),
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

  /// 만든 이벤트를 모두 캘린더에서 지우고 연동 기록도 비운다.
  Future<void> removeAllEvents() async {
    for (final l in _links.values) {
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

  static String _title(Todo t) => t.done ? '✔ ${t.text}' : t.text;

  static String _signature(Todo t, String calendarId) => '$calendarId|${t.date}|${_title(t)}';

  /// 현재 투두에 맞춰 캘린더를 갱신한다. 항목 하나가 실패해도 나머지는 계속한다.
  Future<void> sync(List<Todo> todos) async {
    if (!_enabled || _calendarId.isEmpty) return;
    if (!await _service.hasPermission()) return;
    var changed = false;

    final alive = {for (final t in todos) t.id};
    for (final id in _links.keys.toList()) {
      if (alive.contains(id)) continue;
      try {
        await _service.delete(_links[id]!.eventId);
        _links.remove(id);
        changed = true;
      } on Exception catch (e) {
        debugPrint('캘린더 이벤트 삭제 실패: $e');
      }
    }

    for (final t in todos) {
      final sig = _signature(t, _calendarId);
      final link = _links[t.id];
      if (link?.signature == sig) continue;
      try {
        final day = parseDateKey(t.date);
        if (link != null && link.calendarId == _calendarId && await _service.update(eventId: link.eventId, title: _title(t), day: day)) {
          _links[t.id] = _Link(link.eventId, _calendarId, sig);
        } else {
          if (link != null && link.calendarId != _calendarId) await _service.delete(link.eventId);
          final id = await _service.create(calendarId: _calendarId, title: _title(t), day: day);
          _links[t.id] = _Link(id, _calendarId, sig);
        }
        changed = true;
      } on Exception catch (e) {
        debugPrint('캘린더 이벤트 갱신 실패(${t.text}): $e');
      }
    }

    if (changed) {
      await _save();
      notifyListeners();
    }
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
  const _Link(this.eventId, this.calendarId, this.signature);
  final String eventId;
  final String calendarId;
  final String signature;

  Map<String, dynamic> toJson() => {'event': eventId, 'calendar': calendarId, 'sig': signature};

  factory _Link.fromJson(Map<String, dynamic> j) =>
      _Link((j['event'] as String?) ?? '', (j['calendar'] as String?) ?? '', (j['sig'] as String?) ?? '');
}
