import 'package:flutter/foundation.dart';

import '../../../../data/repositories/journal_repository.dart';
import '../../../../data/repositories/calendar_repository.dart';
import '../../../../domain/models/journal_models.dart';

/// 투두 한 개를 새로 만들거나 고치는 대화상자의 상태와 저장 동작.
class TodoEditorViewModel extends ChangeNotifier {
  TodoEditorViewModel(
    this._journal, {
    required String defaultDate,
    this.existing,
    this.calendar,
  }) : text = existing?.text ?? '',
       date = existing?.date ?? defaultDate,
       time = existing?.time ?? '' {
    calendar?.addListener(notifyListeners);
  }

  final JournalRepository _journal;
  final CalendarRepository? calendar;
  final Todo? existing;

  String text;
  String date;
  String time; // 'HH:mm' 또는 빈 문자열(종일)
  String? saveError;

  bool get isNew => existing == null;
  bool get hasTime => time.isNotEmpty;
  bool get scheduleReadOnly =>
      existing != null &&
      (calendar?.isTodoScheduleReadOnly(existing!.id) ?? false);

  void setDate(String d) {
    if (scheduleReadOnly) return;
    date = d;
    notifyListeners();
  }

  void setTime(String t) {
    if (scheduleReadOnly) return;
    time = t;
    notifyListeners();
  }

  void clearTime() => setTime('');

  /// 내용이 비어 있으면 저장하지 않고 false를 돌려준다.
  Future<bool> save() async {
    saveError = null;
    final t = text.trim();
    if (t.isEmpty) return false;
    final e = existing;
    if (e == null) {
      await _journal.addTodo(t, date, time: time);
    } else {
      final saved = await _journal.patchTodo(
        e.id,
        text: t != e.text ? t : null,
        date: !scheduleReadOnly && date != e.date ? date : null,
        time: !scheduleReadOnly && time != e.time ? time : null,
      );
      if (saved == null) {
        saveError = '이 투두는 이미 삭제되었어요';
        return false;
      }
    }
    return true;
  }

  Future<void> delete() async {
    final e = existing;
    if (e != null) await _journal.deleteTodo(e.id);
  }

  @override
  void dispose() {
    calendar?.removeListener(notifyListeners);
    super.dispose();
  }
}
