import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/journal_repository.dart';
import '../../../../domain/models/journal_models.dart';
import '../../templates/views/templates_screen.dart';
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

Future<void> showTodoDialog(BuildContext context, String date, {Todo? existing}) async {
  final journal = context.read<JournalRepository>();
  final ctrl = TextEditingController(text: existing?.text ?? '');
  var pickedDate = existing?.date ?? date;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (_, setState) => AlertDialog(
        title: Text(existing == null ? '새 투두' : '투두 편집'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: '할 일')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text(pickedDate),
            onPressed: () async {
              final p = await showDatePicker(
                context: dialogContext,
                initialDate: DateTime.parse(pickedDate),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (p != null) {
                setState(() => pickedDate =
                    '${p.year.toString().padLeft(4, '0')}-${p.month.toString().padLeft(2, '0')}-${p.day.toString().padLeft(2, '0')}');
              }
            },
          ),
        ]),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () async {
                await journal.deleteTodo(existing.id);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('삭제'),
            ),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              if (existing == null) {
                await journal.addTodo(text, pickedDate);
              } else {
                await journal.updateTodo(existing.copyWith(text: text, date: pickedDate));
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    ),
  );
  ctrl.dispose();
}
