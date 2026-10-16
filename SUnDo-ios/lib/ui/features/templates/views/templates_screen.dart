import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/routine_repository.dart';
import '../../../../data/repositories/template_repository.dart';
import '../../../../domain/models/habit.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets.dart';
import '../../habit_form/views/habit_form_screen.dart';
import '../view_models/templates_view_model.dart';

Future<void> openTemplates(BuildContext context) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => ChangeNotifierProvider(
      create: (c) => TemplatesViewModel(c.read<TemplateRepository>(), c.read<RoutineRepository>()),
      child: const TemplatesScreen(),
    ),
  ));
}

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TemplatesViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('추천 템플릿'),
        actions: [
          TextButton(
            onPressed: vm.selectedCount == 0
                ? null
                : () async {
                    final n = await vm.addSelected();
                    if (context.mounted) {
                      showToast(context, '루틴 $n개를 추가했어요');
                      Navigator.pop(context);
                    }
                  },
            child: Text('추가 (${vm.selectedCount})'),
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
                Text('눌러서 고른 뒤 오른쪽 위의 추가를 누르세요. 길게 누르면 고쳐서 추가할 수 있어요.',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                for (final c in vm.categories) ...[
                  SectionTitle('${c.emoji} ${c.title}'),
                  for (final h in c.habits)
                    _TemplateTile(
                      habit: h,
                      selected: vm.isSelected(h),
                      onTap: () => vm.toggle(h),
                      onLongPress: () => openHabitForm(context, template: h),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.habit, required this.selected, required this.onTap, required this.onLongPress});
  final Habit habit;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: hexColor(habit.color),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Text(habit.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(habit.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.rowText)),
                  Text(
                    [habit.repeat.summary, if (habit.time.isNotEmpty) habit.time, if (habit.context.isNotEmpty) habit.context].join('  '),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
                  ),
                ]),
              ),
              Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: AppColors.green),
            ]),
          ),
        ),
      ),
    );
  }
}
