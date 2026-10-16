import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/journal_repository.dart';
import '../../../../domain/models/date_key.dart';
import '../../../../domain/models/journal_models.dart';
import '../../templates/views/templates_screen.dart';
import '../view_models/todo_editor_view_model.dart';
import 'habit_form_screen.dart';

Future<void> showAddMenu(BuildContext context, String date) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🌿', style: TextStyle(fontSize: 24)),
              title: const Text('새 습관'),
              onTap: () {
                Navigator.pop(sheetContext);
                openHabitForm(context);
              },
            ),
            ListTile(
              leading: const Text('☑️', style: TextStyle(fontSize: 24)),
              title: const Text('투두'),
              onTap: () {
                Navigator.pop(sheetContext);
                showTodoDialog(context, date);
              },
            ),
            ListTile(
              leading: const Text('✨', style: TextStyle(fontSize: 24)),
              title: const Text('추천 템플릿에서 고르기'),
              onTap: () {
                Navigator.pop(sheetContext);
                openTemplates(context);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showTodoDialog(BuildContext context, String date, {Todo? existing}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ChangeNotifierProvider(
      create: (c) => TodoEditorViewModel(c.read<JournalRepository>(), defaultDate: date, existing: existing),
      child: const _TodoDialog(),
    ),
  );
}

class _TodoDialog extends StatelessWidget {
  const _TodoDialog();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TodoEditorViewModel>();
    return AlertDialog(
      title: Text(vm.isNew ? '새 투두' : '투두 편집'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(
          initialValue: vm.text,
          autofocus: true,
          decoration: const InputDecoration(labelText: '할 일'),
          onChanged: (v) => vm.text = v,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.event),
          label: Text(vm.date),
          onPressed: () async {
            final p = await showDatePicker(
              context: context,
              initialDate: parseDateKey(vm.date),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (p != null) vm.setDate(dateKey(p));
          },
        ),
      ]),
      actions: [
        if (!vm.isNew)
          TextButton(
            onPressed: () async {
              await vm.delete();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(
          onPressed: () async {
            if (await vm.save() && context.mounted) Navigator.pop(context);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}
