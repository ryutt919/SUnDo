import 'package:flutter/foundation.dart';

/// 일괄 삭제 화면에 보이는 항목 한 줄.
class ManageItem {
  const ManageItem({required this.id, required this.title, this.subtitle = '', this.leading = ''});
  final String id;
  final String title;
  final String subtitle;
  final String leading; // 이모지 등
}

/// 항목을 여러 개 골라 한 번에 지우는 화면의 상태. 투두와 루틴이 함께 쓴다.
class BulkDeleteViewModel extends ChangeNotifier {
  BulkDeleteViewModel({required List<ManageItem> Function() items, required Future<void> Function(Set<String>) onDelete})
      : _items = items,
        _onDelete = onDelete;

  final List<ManageItem> Function() _items;
  final Future<void> Function(Set<String>) _onDelete;
  final Set<String> _selected = {};

  /// 저장소가 바뀌어 항목이 사라지면 선택에서도 뺀다.
  List<ManageItem> get items {
    final list = _items();
    _selected.retainAll({for (final i in list) i.id});
    return list;
  }

  Set<String> get selected => Set.unmodifiable(_selected);
  int get selectedCount => _selected.length;
  bool isSelected(String id) => _selected.contains(id);
  bool get allSelected => items.isNotEmpty && _selected.length == items.length;

  void toggle(String id) {
    if (!_selected.remove(id)) _selected.add(id);
    notifyListeners();
  }

  void toggleAll() {
    final all = items;
    if (_selected.length == all.length) {
      _selected.clear();
    } else {
      _selected
        ..clear()
        ..addAll(all.map((i) => i.id));
    }
    notifyListeners();
  }

  /// 선택한 항목을 지우고 지운 개수를 돌려준다.
  Future<int> deleteSelected() async {
    final ids = Set<String>.of(_selected);
    if (ids.isEmpty) return 0;
    await _onDelete(ids);
    _selected.clear();
    notifyListeners();
    return ids.length;
  }
}
