import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/routine_repository.dart';
import '../../../core/widgets.dart';
import '../view_models/modes_view_model.dart';

/// 루틴 모드 선택/관리 시트. 모드를 누르면 바로 적용된다.
Future<void> showModesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider(
      create: (c) => ModesViewModel(c.read<RoutineRepository>()),
      child: const _ModesSheet(),
    ),
  );
}

class _ModesSheet extends StatelessWidget {
  const _ModesSheet();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ModesViewModel>();
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('루틴 모드', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('모드를 누르면 바로 적용돼요. 습관마다 적용할 모드를 고를 수 있어요.',
                style: TextStyle(fontSize: 12, color: cs.outline)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final m in vm.modes)
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: m.id == vm.activeModeId ? cs.primary : cs.outlineVariant),
                      ),
                      child: ListTile(
                        onTap: () async {
                          await vm.apply(m.id);
                          if (context.mounted) Navigator.pop(context);
                        },
                        leading: Icon(m.id == vm.activeModeId ? Icons.check_circle : Icons.circle_outlined,
                            color: m.id == vm.activeModeId ? cs.primary : null),
                        title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              final n = await promptDialog(context, '모드 이름', initial: m.name);
                              if (n != null) await vm.rename(m.id, n);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: !vm.canDelete
                                ? null
                                : () async {
                                    if (await confirmDialog(context, '이 모드를 삭제할까요? 습관은 지워지지 않아요.', ok: '삭제')) {
                                      await vm.delete(m.id);
                                    }
                                  },
                          ),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: !vm.canAdd
                    ? null
                    : () async {
                        final n = await promptDialog(context, '새 모드 이름');
                        if (n != null) await vm.add(n);
                      },
                icon: const Icon(Icons.add),
                label: Text('모드 추가 (${vm.modes.length}/${vm.maxModes})'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
