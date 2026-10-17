import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_theme.dart';
import '../../../core/widgets.dart';
import '../view_models/bulk_delete_view_model.dart';

/// "관리" 버튼으로 여는 일괄 삭제 화면. 항목을 여러 개 고른 뒤 한 번에 지운다.
/// [changes]에 저장소를 넘기면 그 저장소가 바뀔 때 목록을 다시 그린다.
Future<void> openBulkDelete(
  BuildContext context, {
  required String title,
  required String emptyText,
  required List<ManageItem> Function() items,
  required Future<void> Function(Set<String>) onDelete,
  required Listenable changes,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => BulkDeleteViewModel(items: items, onDelete: onDelete),
        child: _BulkDeleteScreen(title: title, emptyText: emptyText, changes: changes),
      ),
    ),
  );
}

class _BulkDeleteScreen extends StatelessWidget {
  const _BulkDeleteScreen({required this.title, required this.emptyText, required this.changes});
  final String title;
  final String emptyText;
  final Listenable changes;

  Future<void> _confirmDelete(BuildContext context, BulkDeleteViewModel vm) async {
    final n = vm.selectedCount;
    if (n == 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$n개를 삭제할까요?'),
        content: const Text('지운 항목은 되돌릴 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final count = await vm.deleteSelected();
    if (context.mounted) showToast(context, '$count개를 삭제했어요');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([changes, context.read<BulkDeleteViewModel>()]),
      builder: (context, _) {
        final vm = context.read<BulkDeleteViewModel>();
        final items = vm.items;
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              if (items.isNotEmpty)
                TextButton(onPressed: vm.toggleAll, child: Text(vm.allSelected ? '전체 해제' : '전체 선택')),
            ],
          ),
          body: items.isEmpty
              ? Center(child: Text(emptyText, style: TextStyle(color: cs.outline)))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final it = items[i];
                        return CheckboxListTile(
                          value: vm.isSelected(it.id),
                          onChanged: (_) => vm.toggle(it.id),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppColors.red,
                          secondary: it.leading.isEmpty ? null : Text(it.leading, style: const TextStyle(fontSize: 22)),
                          title: Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: it.subtitle.isEmpty ? null : Text(it.subtitle),
                        );
                      },
                    ),
                  ),
                ),
          floatingActionButton: items.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: vm.selectedCount == 0 ? null : () => _confirmDelete(context, vm),
                  backgroundColor: vm.selectedCount == 0 ? cs.surfaceContainerHighest : AppColors.red,
                  foregroundColor: vm.selectedCount == 0 ? cs.outline : Colors.white,
                  icon: const Icon(Icons.delete),
                  label: Text(vm.selectedCount == 0 ? '삭제할 항목을 고르세요' : '선택 삭제 (${vm.selectedCount})'),
                ),
        );
      },
    );
  }
}
