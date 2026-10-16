import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/routine_repository.dart';
import '../../../../domain/models/date_key.dart';
import '../../../../domain/models/habit.dart';
import '../../../../domain/models/repeat_rule.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets.dart';
import '../view_models/habit_form_view_model.dart';

Future<void> openHabitForm(BuildContext context, {String? habitId, Habit? template}) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => ChangeNotifierProvider(
      create: (c) => HabitFormViewModel(c.read<RoutineRepository>(), habitId: habitId, template: template),
      child: const HabitFormScreen(),
    ),
  ));
}

class HabitFormScreen extends StatelessWidget {
  const HabitFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HabitFormViewModel>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(vm.isNew ? '새 습관' : '습관 편집'),
        actions: [
          if (!vm.isNew)
            PopupMenuButton<String>(
              onSelected: (v) => _menu(context, vm, v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'dup', child: Text('복제')),
                PopupMenuItem(value: 'finish', child: Text('오늘까지만 하고 종료')),
                PopupMenuItem(value: 'archive', child: Text('보관')),
                PopupMenuItem(value: 'delete', child: Text('삭제(기록 포함)')),
              ],
            ),
          TextButton(
            onPressed: () async {
              final err = vm.validate();
              if (err != null) {
                showToast(context, err);
                return;
              }
              await vm.save();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 72,
                    child: TextFormField(
                      initialValue: vm.emoji,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24),
                      decoration: const InputDecoration(labelText: '이모지'),
                      onChanged: (v) => vm.emoji = v,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: vm.name,
                      decoration: const InputDecoration(labelText: '이름', hintText: '예: 아침에 물 한 잔'),
                      onChanged: (v) => vm.name = v,
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _TimeField(label: '시각', value: vm.time, onChanged: (v) => vm.update(() => vm.time = v))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: vm.context,
                      decoration: const InputDecoration(labelText: '또는 상황', hintText: '출근길에'),
                      onChanged: (v) => vm.context = v,
                    ),
                  ),
                ]),
                const SectionTitle('반복'),
                DropdownButtonFormField<RepeatType>(
                  initialValue: vm.repeat.type,
                  items: [for (final t in RepeatType.values) DropdownMenuItem(value: t, child: Text(t.label))],
                  onChanged: (t) => vm.update(() => vm.repeat = vm.repeat.copyWith(type: t)),
                ),
                const SizedBox(height: 10),
                if (vm.repeat.type == RepeatType.weekdays)
                  Wrap(spacing: 6, children: [
                    for (final d in [1, 2, 3, 4, 5, 6, 0])
                      FilterChip(
                        label: Text(koWeekdays[d]),
                        selected: vm.repeat.days.contains(d),
                        onSelected: (on) => vm.toggleWeekday(d, on),
                      ),
                  ]),
                if (vm.repeat.type == RepeatType.weekly)
                  _NumberField(
                    label: '주 몇 회',
                    value: vm.repeat.times,
                    min: 1,
                    max: 7,
                    onChanged: (n) => vm.update(() => vm.repeat = vm.repeat.copyWith(times: n)),
                  ),
                if (vm.repeat.type == RepeatType.interval)
                  _NumberField(
                    label: '며칠마다 (시작일 기준)',
                    value: vm.repeat.every,
                    min: 2,
                    max: 365,
                    onChanged: (n) => vm.update(() => vm.repeat = vm.repeat.copyWith(every: n)),
                  ),
                if (vm.repeat.type == RepeatType.monthDays)
                  TextFormField(
                    initialValue: vm.repeat.monthDays.join(', '),
                    decoration: const InputDecoration(labelText: '매월 날짜 (쉼표로 구분)', hintText: '1, 15'),
                    onChanged: (v) {
                      final days = v
                          .split(',')
                          .map((s) => int.tryParse(s.trim()))
                          .whereType<int>()
                          .where((n) => n >= 1 && n <= 31)
                          .toList();
                      vm.repeat = vm.repeat.copyWith(monthDays: days);
                    },
                  ),
                const SectionTitle('난이도별 내용 (선택)'),
                for (final l in HabitLevel.values) ...[
                  TextFormField(
                    initialValue: vm.levels[l.name],
                    decoration: InputDecoration(
                      labelText: l.label,
                      hintText: switch (l) {
                        HabitLevel.mini => '예: 1분만',
                        HabitLevel.plus => '예: 10분',
                        HabitLevel.max => '예: 30분',
                      },
                    ),
                    onChanged: (v) => vm.levels[l.name] = v,
                  ),
                  const SizedBox(height: 8),
                ],
                const SectionTitle('대체 이름 (쉼표로 구분)'),
                TextFormField(
                  initialValue: vm.alts,
                  decoration: const InputDecoration(hintText: '예: 요가, 산책'),
                  onChanged: (v) => vm.alts = v,
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _TimeField(label: '알람', value: vm.alarm, onChanged: (v) => vm.update(() => vm.alarm = v))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NumberField(
                      label: '타이머(분)',
                      value: vm.timerMin,
                      min: 0,
                      max: 240,
                      onChanged: (n) => vm.timerMin = n,
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: vm.unit,
                  decoration: const InputDecoration(labelText: '수치 기록 단위 (선택)', hintText: '예: 보, kg, 쪽'),
                  onChanged: (v) => vm.unit = v,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: vm.reason,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '이 습관을 하는 이유 (선택)'),
                  onChanged: (v) => vm.reason = v,
                ),
                const SectionTitle('색상'),
                Wrap(spacing: 10, children: [
                  for (final c in habitColors)
                    GestureDetector(
                      onTap: () => vm.update(() => vm.color = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: hexColor(c),
                          shape: BoxShape.circle,
                          border: Border.all(color: vm.color == c ? cs.onSurface : cs.outlineVariant, width: vm.color == c ? 2.5 : 1),
                        ),
                      ),
                    ),
                ]),
                const SectionTitle('적용할 루틴 모드 (선택 안 하면 모두)'),
                Wrap(spacing: 6, children: [
                  for (final m in context.read<RoutineRepository>().modes)
                    FilterChip(
                      label: Text(m.name),
                      selected: vm.modes.contains(m.id),
                      onSelected: (on) => vm.toggleMode(m.id, on),
                    ),
                ]),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext context, HabitFormViewModel vm, String v) async {
    final nav = Navigator.of(context);
    switch (v) {
      case 'dup':
        await vm.duplicate();
        nav.pop();
      case 'finish':
        if (await confirmDialog(context, '오늘까지만 하고 종료할까요? 지난 기록은 남아요.', ok: '종료')) {
          await vm.finishToday();
          nav.pop();
        }
      case 'archive':
        await vm.archive();
        nav.pop();
      case 'delete':
        if (await confirmDialog(context, '이 습관과 모든 기록을 삭제할까요? 되돌릴 수 없어요.', ok: '삭제')) {
          await vm.delete();
          nav.pop();
        }
    }
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.value, required this.onChanged});
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final parts = value.split(':');
        final initial = parts.length == 2
            ? TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]))
            : TimeOfDay.now();
        final t = await showTimePicker(context: context, initialTime: initial);
        if (t != null) onChanged('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value.isEmpty ? const Icon(Icons.schedule, size: 18) : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => onChanged('')),
        ),
        child: Text(value.isEmpty ? '없음' : value),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.label, required this.value, required this.min, required this.max, required this.onChanged});
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: '$value',
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (v) {
        final n = int.tryParse(v);
        if (n != null) onChanged(n.clamp(min, max));
      },
    );
  }
}
