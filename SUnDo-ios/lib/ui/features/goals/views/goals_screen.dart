import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/journal_models.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets.dart';
import '../view_models/goals_view_model.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GoalsViewModel>();
    final goals = vm.goals;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('계획', style: TextStyle(fontWeight: FontWeight.w900))),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-goals',
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        onPressed: () async {
          final t = await promptDialog(context, '${vm.period.label} 계획 제목');
          if (t != null) await vm.addGoal(t);
        },
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                SegmentedButton<GoalPeriod>(
                  showSelectedIcon: false,
                  segments: [for (final p in GoalPeriod.values) ButtonSegment(value: p, label: Text(p.label))],
                  selected: {vm.period},
                  onSelectionChanged: (s) => vm.setPeriod(s.first),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  IconButton(iconSize: 32, tooltip: '이전', icon: const Icon(Icons.arrow_left), onPressed: () => vm.shift(-1)),
                  Expanded(
                    child: InkWell(
                      onTap: vm.goCurrent,
                      child: Center(child: Text(vm.periodTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                    ),
                  ),
                  IconButton(iconSize: 32, tooltip: '다음', icon: const Icon(Icons.arrow_right), onPressed: () => vm.shift(1)),
                ]),
                if (goals.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Text('${(vm.overallProgress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(width: 10),
                      Expanded(child: ProgressBar(value: vm.overallProgress)),
                      const SizedBox(width: 10),
                      Text('완료 ${vm.completion.done}/${vm.completion.total}', style: TextStyle(color: cs.outline)),
                    ]),
                  ),
                if (goals.isEmpty)
                  const EmptyHint('이 기간의 계획이 없어요.\n오른쪽 아래 + 버튼으로 계획을 추가해 보세요.'),
                for (final g in vm.openGoals) _GoalCard(goal: g, vm: vm, outline: cs.outline),
                if (vm.doneGoals.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 18, 0, 6),
                    child: Text('완료한 계획 ${vm.doneGoals.length}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: cs.outline)),
                  ),
                  for (final g in vm.doneGoals) _GoalCard(goal: g, vm: vm, outline: cs.outline),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.vm, required this.outline});
  final Goal goal;
  final GoalsViewModel vm;
  final Color outline;

  @override
  Widget build(BuildContext context) {
    final done = goal.done;
    return Card(
      color: done ? AppColors.green.withValues(alpha: 0.12) : null,
      shape: done
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.green.withValues(alpha: 0.6), width: 1.5),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Checkbox(
              value: done,
              activeColor: AppColors.green,
              visualDensity: VisualDensity.compact,
              onChanged: (_) => vm.toggleGoal(goal),
            ),
            Expanded(
              child: Text(goal.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? outline : null,
                  )),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'rename') {
                  final t = await promptDialog(context, '계획 제목', initial: goal.title);
                  if (t != null) await vm.rename(goal, t);
                } else if (v == 'delete') {
                  if (await confirmDialog(context, '이 계획을 삭제할까요?', ok: '삭제')) await vm.deleteGoal(goal.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('제목 수정')),
                PopupMenuItem(value: 'delete', child: Text('삭제')),
              ],
            ),
          ]),
          if (goal.items.isNotEmpty) ...[
            ProgressBar(value: goal.progress),
            const SizedBox(height: 4),
          ],
          for (var i = 0; i < goal.items.length; i++)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: goal.items[i].done,
              onChanged: (_) => vm.toggleItem(goal, i),
              title: Text(goal.items[i].text,
                  style: TextStyle(decoration: goal.items[i].done ? TextDecoration.lineThrough : null)),
              secondary: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => vm.removeItem(goal, i),
              ),
            ),
          TextButton.icon(
            onPressed: () async {
              final t = await promptDialog(context, '세부 항목');
              if (t != null) await vm.addItem(goal, t);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('세부 항목 추가'),
          ),
        ]),
      ),
    );
  }
}
