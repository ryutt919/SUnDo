import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/routine_repository.dart';
import '../../../core/widgets.dart';

/// 루틴 모드 선택/관리 시트. 모드를 누르면 바로 적용된다.
Future<void> showModesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ModesSheet(),
  );
}

class _ModesSheet extends StatelessWidget {
  const _ModesSheet();

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<RoutineRepository>();
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
                  for (final m in repo.modes)
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: m.id == repo.activeModeId ? cs.primary : cs.outlineVariant),
                      ),
                      child: ListTile(
                        onTap: () async {
                          await repo.setActiveMode(m.id);
                          if (context.mounted) Navigator.pop(context);
                        },
                        leading: Icon(m.id == repo.activeModeId ? Icons.check_circle : Icons.circle_outlined,
                            color: m.id == repo.activeModeId ? cs.primary : null),
                        title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              final n = await promptDialog(context, '모드 이름', initial: m.name);
                              if (n != null) await repo.renameMode(m.id, n);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: repo.modes.length == 1
                                ? null
                                : () async {
                                    if (await confirmDialog(context, '이 모드를 삭제할까요? 습관은 지워지지 않아요.', ok: '삭제')) {
                                      await repo.deleteMode(m.id);
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
                onPressed: repo.modes.length >= RoutineRepository.maxModes
                    ? null
                    : () async {
                        final n = await promptDialog(context, '새 모드 이름');
                        if (n != null) await repo.addMode(n);
                      },
                icon: const Icon(Icons.add),
                label: Text('모드 추가 (${repo.modes.length}/${RoutineRepository.maxModes})'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
