import 'package:flutter/material.dart';

import '../../../../domain/models/date_key.dart';
import '../../../../domain/use_cases/routine_analyzer.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets.dart';
import '../../habit_detail/views/habit_detail_sheet.dart';
import '../../habit_form/views/habit_form_screen.dart';
import '../view_models/home_view_model.dart';

/// 홈의 "주간" 탭. 주 N회 목표를 세운 루틴이 이번 주에 몇 번 채워졌는지 보고, 날짜 칸을 눌러 체크한다.
List<Widget> weeklySlivers(BuildContext context, HomeViewModel vm) {
  const pad = EdgeInsets.symmetric(horizontal: 16);
  final rows = vm.weeklyRows;
  final summary = SliverPadding(
    padding: pad,
    sliver: SliverToBoxAdapter(child: _WeeklySummary(vm: vm)),
  );
  if (rows.isEmpty) {
    return [
      summary,
      const SliverToBoxAdapter(
        child: EmptyHint('이번 주 주간 루틴이 없어요.\n아래 + 버튼에서 "새 주간 루틴"을 만들면\n일주일에 몇 번 할지 목표를 세워 체크할 수 있어요.'),
      ),
    ];
  }
  final wide = MediaQuery.sizeOf(context).width >= 700;
  final tiles = [for (final r in rows) _WeeklyTile(vm: vm, row: r)];
  return [
    summary,
    SliverPadding(
      padding: pad,
      sliver: wide
          ? SliverGrid(
              delegate: SliverChildListDelegate(tiles),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 520,
                mainAxisExtent: 156,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
            )
          : SliverList.separated(
              itemCount: tiles.length,
              itemBuilder: (_, i) => tiles[i],
              separatorBuilder: (_, _) => const SizedBox(height: 8),
            ),
    ),
  ];
}

class _WeeklySummary extends StatelessWidget {
  const _WeeklySummary({required this.vm});
  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final rows = vm.weeklyRows;
    final rate = vm.weeklyRate;
    return Card(
      margin: const EdgeInsets.only(top: 10, bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Text('${(rate * 100).round()}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(width: 12),
            Expanded(child: ProgressBar(value: rate, color: AppColors.green)),
            const SizedBox(width: 12),
            Text('목표 달성 ${vm.weeklyAchieved}/${rows.length}', style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _WeeklyTile extends StatelessWidget {
  const _WeeklyTile({required this.vm, required this.row});
  final HomeViewModel vm;
  final WeeklyRowData row;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = row.progress;
    final h = p.habit;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showHabitDetail(context, h.id, vm.selectedDate),
      onLongPress: () => openHabitForm(context, habitId: h.id),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: hexColor(h.color),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(h.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(h.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.rowText)),
                ),
                Text(p.achieved ? '목표 달성' : '${p.doneCount}/${p.goal}',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: p.achieved ? AppColors.darkGreen : AppColors.rowText)),
                const SizedBox(width: 6),
                _CheckButton(
                  done: row.doneOnSelected,
                  enabled: row.selectedActive,
                  onTap: () => vm.toggleHabit(h.id),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ProgressBar(value: p.rate, color: AppColors.green),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final d in p.days)
                  Expanded(
                    child: _DayCell(
                      day: d,
                      selected: d.date == vm.selectedDate,
                      cs: cs,
                      onTap: () => vm.toggleHabit(h.id, d.date),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.done, required this.enabled, required this.onTap});
  final bool done;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? AppColors.green : Colors.white.withValues(alpha: 0.7),
          border: Border.all(color: AppColors.green, width: 2),
        ),
        child: Icon(Icons.check, color: done ? Colors.white : AppColors.green.withValues(alpha: enabled ? 0.4 : 0.15), size: 26),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.selected, required this.cs, required this.onTap});
  final WeeklyDay day;
  final bool selected;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = parseDateKey(day.date);
    final canTap = day.active && !day.future;
    return GestureDetector(
      onTap: canTap ? onTap : null,
      child: Column(
        children: [
          Text(koWeekdays[sundayZero(d)], style: TextStyle(fontSize: 11, color: AppColors.rowText.withValues(alpha: 0.7))),
          const SizedBox(height: 3),
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: day.done ? AppColors.green : Colors.white.withValues(alpha: day.active ? 0.7 : 0.25),
              border: selected ? Border.all(color: const Color(0xFF5C6166), width: 2) : null,
            ),
            child: day.done
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : Text('${d.day}',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.rowText.withValues(alpha: day.future || day.rest || !day.active ? 0.4 : 0.9))),
          ),
        ],
      ),
    );
  }
}
