import 'package:flutter/foundation.dart';

import '../../../../data/repositories/routine_repository.dart';
import '../../../../data/repositories/template_repository.dart';
import '../../../../domain/models/habit.dart';

class TemplatesViewModel extends ChangeNotifier {
  TemplatesViewModel(TemplateRepository templates, this._routine) : categories = templates.categories();

  final RoutineRepository _routine;
  final List<TemplateCategory> categories;
  final Set<String> _selected = {};

  int get selectedCount => _selected.length;
  bool isSelected(Habit h) => _selected.contains(h.id);

  void toggle(Habit h) {
    _selected.contains(h.id) ? _selected.remove(h.id) : _selected.add(h.id);
    notifyListeners();
  }

  Future<int> addSelected() async {
    var n = 0;
    for (final c in categories) {
      for (final h in c.habits) {
        if (_selected.contains(h.id)) {
          await _routine.addHabit(h);
          n++;
        }
      }
    }
    return n;
  }
}
