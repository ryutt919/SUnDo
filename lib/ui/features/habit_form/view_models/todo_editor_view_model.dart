import 'package:flutter/foundation.dart';

import '../../../../data/repositories/journal_repository.dart';
import '../../../../domain/models/journal_models.dart';

/// 투두 한 개를 새로 만들거나 고치는 대화상자의 상태와 저장 동작.
class TodoEditorViewModel extends ChangeNotifier {
  TodoEditorViewModel(this._journal, {required String defaultDate, this.existing})
      : text = existing?.text ?? '',
        date = existing?.date ?? defaultDate;

  final JournalRepository _journal;
  final Todo? existing;

  String text;
  String date;

  bool get isNew => existing == null;

  void setDate(String d) {
    date = d;
    notifyListeners();
  }

  /// 내용이 비어 있으면 저장하지 않고 false를 돌려준다.
  Future<bool> save() async {
    final t = text.trim();
    if (t.isEmpty) return false;
    final e = existing;
    if (e == null) {
      await _journal.addTodo(t, date);
    } else {
      await _journal.updateTodo(e.copyWith(text: t, date: date));
    }
    return true;
  }

  Future<void> delete() async {
    final e = existing;
    if (e != null) await _journal.deleteTodo(e.id);
  }
}
