import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/date_key.dart';
import '../../../../domain/models/journal_models.dart';
import '../../../../domain/use_cases/stats_use_case.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets.dart';
import '../../review/views/review_view.dart' show moodEmojis;
import '../view_models/stats_view_model.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StatsViewModel>();
    final s = vm.summary;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final lv = vm.level;

    final cards = <Widget>[
      _Card(
        title: '달성률',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${(s.averageRate * 100).round()}%', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
          Text('초록불 ${s.greenDays}일 / 기록된 ${s.ratedDays}일 (초록 60% 이상, 노랑 20% 이상)',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 10),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (var i = 0; i < s.dates.length; i++)
              TrafficDot(light: s.lights[i], label: '${parseDateKey(s.dates[i]).day}', size: 24),
          ]),
        ]),
      ),
      _Card(
        title: '루틴별 달성률',
        child: s.habitStats.isEmpty
            ? const Text('루틴이 없어요.')
            : Column(children: [
                for (final h in s.habitStats)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Column(children: [
                      Row(children: [
                        Expanded(child: Text('${h.habit.emoji} ${h.habit.name}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text('${(h.rate * 100).round()}%  (${h.done}/${h.due})', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 4),
                      ProgressBar(value: h.rate),
                    ]),
                  ),
              ]),
      ),
      _Card(
        title: '${vm.calendarMonth.year}년 ${vm.calendarMonth.month}월 투두 캘린더',
        trailing: _MonthNav(vm: vm),
        child: _TodoCalendarBody(vm: vm),
      ),
      _Card(
        title: '${vm.calendarMonth.year}년 ${vm.calendarMonth.month}월 계획 캘린더',
        trailing: _MonthNav(vm: vm),
        child: _PlanCalendarBody(vm: vm),
      ),
      _Card(
        title: '${vm.calendarMonth.year}년 ${vm.calendarMonth.month}월 무드 캘린더',
        trailing: _MonthNav(vm: vm),
        child: _MoodCalendar(cells: vm.moodCalendar),
      ),
      _Card(
        title: '배지 (누적 체크 ${vm.totalChecks}회)',
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final b in vm.badges)
            Opacity(
              opacity: b.earned ? 1 : 0.4,
              child: Chip(
                label: Text(b.label, style: const TextStyle(fontSize: 12)),
                backgroundColor: b.earned ? AppColors.green.withValues(alpha: 0.18) : null,
              ),
            ),
        ]),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('통계', style: TextStyle(fontWeight: FontWeight.w900))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Text(lv.emoji, style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${lv.name} 레벨 / 루틴 ${vm.routineDay}일차',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('연속 초록불 ${vm.streak}일, 다음 레벨까지 체크 ${(lv.next - vm.totalChecks).clamp(0, 99999)}회',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                    ]),
                  ),
                ]),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<StatsRange>(
                showSelectedIcon: false,
                segments: [for (final r in StatsRange.values) ButtonSegment(value: r, label: Text(r.label))],
                selected: {vm.range},
                onSelectionChanged: (v) => vm.setRange(v.first),
              ),
            ),
            const SizedBox(height: 12),
            if (wide)
              // 카드 폭은 화면 전체가 아니라 실제 본문 폭(내비게이션 레일을 뺀 폭)에서 계산한다
              LayoutBuilder(
                builder: (_, box) => Wrap(spacing: 12, runSpacing: 0, children: [
                  for (final c in cards) SizedBox(width: (box.maxWidth - 12) / 2, child: c),
                ]),
              )
            else
              ...cards,
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
              ?trailing,
            ]),
            const SizedBox(height: 10),
            child,
          ]),
        ),
      );
}

class _MoodCalendar extends StatelessWidget {
  const _MoodCalendar({required this.cells});
  final List<({int day, int mood})?> cells;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Row(children: [for (final d in koWeekdays) Expanded(child: Center(child: Text(d, style: TextStyle(fontSize: 12, color: cs.outline))))]),
      const SizedBox(height: 4),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        children: [
          for (final c in cells)
            c == null
                ? const SizedBox.shrink()
                : Container(
                    decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                    child: Stack(children: [
                      Positioned(left: 4, top: 2, child: Text('${c.day}', style: TextStyle(fontSize: 9, color: cs.outline))),
                      Center(child: Text(c.mood > 0 ? moodEmojis[c.mood - 1] : '', style: const TextStyle(fontSize: 18))),
                    ]),
                  ),
        ],
      ),
    ]);
  }
}

class _MonthNav extends StatelessWidget {
  const _MonthNav({required this.vm});
  final StatsViewModel vm;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.chevron_left), onPressed: () => vm.shiftMonth(-1)),
        IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.chevron_right), onPressed: () => vm.shiftMonth(1)),
      ]);
}

Color _toneColor(CalendarTone t, ColorScheme cs) => switch (t) {
      CalendarTone.done => AppColors.green,
      CalendarTone.partial => AppColors.yellow,
      CalendarTone.missed => AppColors.red,
      CalendarTone.pending => AppColors.gray,
      CalendarTone.none => cs.surfaceContainerHighest.withValues(alpha: 0.5),
    };

/// 요일 머리글과 달력 칸. [cellBuilder]는 앞쪽 빈칸을 뺀 칸마다 불린다.
class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.cells, required this.cellBuilder});
  final List<Object?> cells;
  final Widget Function(Object cell) cellBuilder;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Row(children: [for (final d in koWeekdays) Expanded(child: Center(child: Text(d, style: TextStyle(fontSize: 12, color: cs.outline))))]),
      const SizedBox(height: 4),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        children: [for (final c in cells) c == null ? const SizedBox.shrink() : cellBuilder(c)],
      ),
    ]);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.tone, required this.label, required this.onTap});
  final int day;
  final CalendarTone tone;
  final String label; // 칸 가운데 문구(예: "2/3")
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filled = tone == CalendarTone.done || tone == CalendarTone.partial || tone == CalendarTone.missed;
    final fg = filled ? Colors.white : cs.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: _toneColor(tone, cs).withValues(alpha: tone == CalendarTone.pending ? 0.55 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(children: [
          Positioned(left: 4, top: 2, child: Text('$day', style: TextStyle(fontSize: 9, color: filled ? Colors.white70 : cs.outline))),
          Center(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg))),
        ]),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.items);
  final List<(Color, String)> items;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 12, runSpacing: 4, children: [
        for (final (c, t) in items)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(t, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
          ]),
      ]);
}

class _TodoCalendarBody extends StatelessWidget {
  const _TodoCalendarBody({required this.vm});
  final StatsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final t = vm.todoMonthTotals;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t.total == 0 ? '이 달에 날짜가 잡힌 투두가 없어요' : '이 달 투두 ${t.done}/${t.total} 완료 (${(t.done * 100 / t.total).round()}%)',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      _CalendarGrid(
        cells: vm.todoCalendar,
        cellBuilder: (c) {
          final d = c as TodoDayStat;
          return _DayCell(
            day: d.day,
            tone: d.tone,
            label: d.total == 0 ? '' : '${d.done}/${d.total}',
            onTap: d.total == 0 ? null : () => _showTodoDay(context, vm, d.date),
          );
        },
      ),
      const SizedBox(height: 8),
      _Legend([
        (AppColors.green, '모두 완료'),
        (AppColors.yellow, '일부 완료'),
        (AppColors.red, '못 한 날'),
        (AppColors.gray, '예정'),
      ]),
    ]);
  }
}

void _showTodoDay(BuildContext context, StatsViewModel vm, String date) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final todos = vm.todosOn(date);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
              Text('$date 투두 ${todos.where((t) => t.done).length}/${todos.length}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (todos.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('투두가 없어요')),
              for (final t in todos)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.green,
                  value: t.done,
                  onChanged: (_) => vm.toggleTodo(t),
                  title: Text(t.text, style: TextStyle(decoration: t.done ? TextDecoration.lineThrough : null)),
                  subtitle: t.hasTime ? Text(t.time) : null,
                ),
            ]),
          ),
        );
      },
    ),
  );
}

class _PlanCalendarBody extends StatelessWidget {
  const _PlanCalendarBody({required this.vm});
  final StatsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final month = vm.monthGoalProgress;
    final year = vm.yearGoalProgress;
    Widget bar(String label, double? v) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            SizedBox(width: 92, child: Text(label, style: const TextStyle(fontSize: 12))),
            Expanded(child: ProgressBar(value: v ?? 0)),
            SizedBox(width: 44, child: Text(v == null ? '없음' : '${(v * 100).round()}%', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      bar('${vm.calendarMonth.month}월 월간 계획', month),
      bar('${vm.calendarMonth.year}년 연간 계획', year),
      const SizedBox(height: 4),
      Text('칸 색은 그 주 주간 계획의 평균 진행률이에요. 칸을 누르면 그 날의 계획을 봐요', style: TextStyle(fontSize: 11, color: cs.outline)),
      const SizedBox(height: 8),
      _CalendarGrid(
        cells: vm.planCalendar,
        cellBuilder: (c) {
          final d = c as PlanDayStat;
          return _DayCell(
            day: d.day,
            tone: d.tone,
            label: d.goalCount == 0 ? '' : '${(d.progress * 100).round()}%',
            onTap: () => _showPlanDay(context, vm, d.date),
          );
        },
      ),
      const SizedBox(height: 8),
      _Legend([
        (AppColors.green, '모두 달성'),
        (AppColors.yellow, '진행 중'),
        (AppColors.red, '시작 못 함'),
        (AppColors.gray, '예정'),
      ]),
    ]);
  }
}

void _showPlanDay(BuildContext context, StatsViewModel vm, String date) {
  final goals = vm.goalsCovering(date);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
          Text('$date 계획', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (goals.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('이 날을 덮는 계획이 없어요')),
          for (final g in goals)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Chip(label: Text(g.period.label, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact),
                  const SizedBox(width: 8),
                  Expanded(child: Text(g.title, style: TextStyle(fontWeight: FontWeight.w700, decoration: g.done ? TextDecoration.lineThrough : null))),
                  Text('${(g.progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 4),
                ProgressBar(value: g.progress),
                if (g.items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('세부 ${g.items.where((i) => i.done).length}/${g.items.length} 완료',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                  ),
              ]),
            ),
        ]),
      ),
    ),
  );
}
