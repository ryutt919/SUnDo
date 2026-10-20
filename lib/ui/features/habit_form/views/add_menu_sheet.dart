import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/journal_repository.dart';
import '../../../../data/repositories/calendar_repository.dart';
import '../../../../domain/models/date_key.dart';
import '../../../../domain/models/journal_models.dart';
import '../../templates/views/templates_screen.dart';
import '../../../core/widgets.dart';
import '../../../../domain/models/repeat_rule.dart';
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
              title: const Text('새 매일 루틴'),
              onTap: () {
                Navigator.pop(sheetContext);
                openHabitForm(context);
              },
            ),
            ListTile(
              leading: const Text('📅', style: TextStyle(fontSize: 24)),
              title: const Text('새 주간 루틴'),
              subtitle: const Text('일주일에 몇 번 하기로 목표를 세워요'),
              onTap: () {
                Navigator.pop(sheetContext);
                openHabitForm(context, initialRepeat: const RepeatRule(type: RepeatType.weekly, times: 3));
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
      create: (c) => TodoEditorViewModel(c.read<JournalRepository>(), defaultDate: date, existing: existing, calendar: c.read<CalendarRepository?>()),
      child: const _TodoDialog(),
    ),
  );
}

class _TodoDialog extends StatelessWidget {
  const _TodoDialog();

  static String _two(int n) => n.toString().padLeft(2, '0');

  Future<void> _pickTime(BuildContext context, TodoEditorViewModel vm) async {
    final parts = vm.hasTime ? vm.time.split(':') : null;
    final initial = parts == null
        ? TimeOfDay.now()
        : TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final p = await showTimePicker(context: context, initialTime: initial);
    if (p != null) vm.setTime('${_two(p.hour)}:${_two(p.minute)}');
  }

  Future<void> _pickDate(BuildContext context, TodoEditorViewModel vm) async {
    final p = await showDatePicker(
      context: context,
      initialDate: parseDateKey(vm.date),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (p != null) vm.setDate(dateKey(p));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TodoEditorViewModel>();
    return AlertDialog(
      title: Text(vm.isNew ? '투두 추가' : '투두 편집'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          onPressed: vm.scheduleReadOnly ? null : () => _pickDate(context, vm),
        ),
        const SizedBox(height: 8),
        if (vm.hasTime)
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.schedule),
                label: Text(vm.time),
                onPressed: vm.scheduleReadOnly ? null : () => _pickTime(context, vm),
              ),
            ),
            IconButton(tooltip: '시간 지우기(종일)', icon: const Icon(Icons.close), onPressed: vm.scheduleReadOnly ? null : vm.clearTime),
          ])
        else
          OutlinedButton.icon(
            icon: const Icon(Icons.more_time),
            label: const Text('시간 추가 (없으면 종일)'),
            onPressed: vm.scheduleReadOnly ? null : () => _pickTime(context, vm),
          ),
        if (vm.scheduleReadOnly) ...[
          const SizedBox(height: 8),
          const Text('읽기 전용 캘린더 일정이에요. 날짜와 시간은 원본 캘린더에서 바꿔 주세요'),
        ],
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
            final saved = await vm.save();
            if (!context.mounted) return;
            if (saved) {
              Navigator.pop(context);
            } else if (vm.saveError != null) {
              showToast(context, vm.saveError!);
            }
          },
          child: Text(vm.isNew ? '추가' : '저장'),
        ),
      ],
    );
  }
}
