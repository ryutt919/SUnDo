import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/date_key.dart';
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
        title: '습관별 달성률',
        child: s.habitStats.isEmpty
            ? const Text('습관이 없어요.')
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
        title: '${vm.calendarMonth.year}년 ${vm.calendarMonth.month}월 무드 캘린더',
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.chevron_left), onPressed: () => vm.shiftMonth(-1)),
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.chevron_right), onPressed: () => vm.shiftMonth(1)),
        ]),
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
