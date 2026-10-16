import 'package:flutter/material.dart';

import '../../../../domain/models/date_key.dart';
import '../../../core/app_theme.dart';
import '../view_models/home_view_model.dart';

/// 주간 보기: 루틴 x 7일 격자. 칸을 누르면 그 날의 체크를 바꾼다.
class WeekGrid extends StatelessWidget {
  const WeekGrid({super.key, required this.vm});
  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final habits = vm.weekGridHabits;
    if (habits.isEmpty) return const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('루틴이 없어요.')));
    final dates = vm.weekDates;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            const Expanded(flex: 3, child: SizedBox()),
            for (final d in dates)
              Expanded(
                child: Column(children: [
                  Text(koWeekdays[sundayZero(parseDateKey(d))], style: TextStyle(fontSize: 12, color: cs.outline)),
                  Text('${parseDateKey(d).day}', style: TextStyle(fontSize: 12, color: cs.outline)),
                ]),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (final h in habits)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            decoration: BoxDecoration(color: hexColor(h.color), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('${h.emoji} ${h.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.rowText)),
                ),
                for (final d in dates) Expanded(child: _Cell(vm: vm, habitId: h.id, emoji: h.emoji, cell: vm.weekGridCell(h, d))),
              ],
            ),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.vm, required this.habitId, required this.emoji, required this.cell});
  final HomeViewModel vm;
  final String habitId;
  final String emoji;
  final WeekGridCell cell;

  @override
  Widget build(BuildContext context) {
    final off = !cell.due && !cell.done;
    return GestureDetector(
      onTap: () => vm.toggleHabit(habitId, cell.date),
      child: Opacity(
        opacity: off ? 0.4 : 1,
        child: Container(
          height: 32,
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: cell.done ? AppColors.green : AppColors.gray, width: 1.5),
          ),
          child: cell.done ? Text(emoji, style: const TextStyle(fontSize: 16)) : null,
        ),
      ),
    );
  }
}
