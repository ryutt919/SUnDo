import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/date_key.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets.dart';
import '../../../../domain/models/habit.dart';
import '../../../../domain/models/repeat_rule.dart';
import '../../habit_form/views/habit_form_screen.dart';
import '../../manage/view_models/bulk_delete_view_model.dart';
import '../../manage/views/bulk_delete_screen.dart';
import '../../habit_form/views/add_menu_sheet.dart';
import '../../habit_detail/views/habit_detail_sheet.dart';
import '../../review/views/review_view.dart';
import '../view_models/home_view_model.dart';
import 'habit_tile.dart';
import 'week_grid.dart';
import 'weekly_section.dart';
import 'modes_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    return Scaffold(
      floatingActionButton: vm.tab != HomeTab.review
          ? FloatingActionButton(
              onPressed: () => showAddMenu(context, vm.selectedDate),
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v.abs() > 300) vm.shiftWeek(v < 0 ? 1 : -1);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Header(vm: vm)),
              SliverToBoxAdapter(child: _WeekStrip(vm: vm)),
              SliverToBoxAdapter(child: _Tabs(vm: vm)),
              if (vm.tab == HomeTab.routine)
                ..._routineSlivers(context, vm)
              else if (vm.tab == HomeTab.weekly)
                ...weeklySlivers(context, vm)
              else
                SliverToBoxAdapter(child: ReviewView(date: vm.selectedDate)),
              const SliverToBoxAdapter(child: SizedBox(height: 90)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _routineSlivers(BuildContext context, HomeViewModel vm) {
    final rows = vm.habitRows;
    final todos = vm.todoRows;
    final pad = const EdgeInsets.symmetric(horizontal: 16);

    final summary = SliverPadding(
      padding: pad,
      sliver: SliverToBoxAdapter(child: _Summary(vm: vm)),
    );
    final toolbar = SliverPadding(
      padding: pad,
      sliver: SliverToBoxAdapter(child: _Toolbar(vm: vm)),
    );
    if (vm.viewMode == HomeViewMode.week) {
      return [summary, toolbar, SliverPadding(padding: pad, sliver: SliverToBoxAdapter(child: WeekGrid(vm: vm)))];
    }
    if (rows.isEmpty && todos.isEmpty) {
      return [
        summary,
        toolbar,
        SliverToBoxAdapter(
          child: EmptyHint(vm.isRestDay
              ? '🌴 쉬는 날이에요. 스트릭은 끊기지 않아요.'
              : '이 날의 루틴이 없어요.\n아래 + 버튼으로 루틴이나 투두를 추가해 보세요.'),
        ),
      ];
    }
    if (vm.editing) {
      return [
        summary,
        toolbar,
        SliverPadding(
          padding: pad,
          sliver: SliverReorderableList(
            itemCount: rows.length,
            onReorderItem: vm.reorder,
            itemBuilder: (c, i) => ReorderableDelayedDragStartListener(
              key: ValueKey(rows[i].habit.id),
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: HabitTile(
                  data: rows[i],
                  editing: true,
                  onEdit: () => openHabitForm(context, habitId: rows[i].habit.id),
                  onToggle: () {},
                  onOpen: () {},
                ),
              ),
            ),
          ),
        ),
      ];
    }
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final tiles = <Widget>[
      for (final r in rows)
        HabitTile(
          data: r,
          editing: false,
          onToggle: () => vm.toggleHabit(r.habit.id),
          onOpen: () => showHabitDetail(context, r.habit.id, vm.selectedDate),
          onEdit: () => openHabitForm(context, habitId: r.habit.id),
        ),
      for (final t in todos)
        TodoTile(
          data: t,
          onToggle: () => vm.toggleTodo(t.todo),
          onEdit: () => showTodoDialog(context, vm.selectedDate, existing: t.todo),
        ),
    ];
    return [
      summary,
      toolbar,
      SliverPadding(
        padding: pad,
        sliver: wide
            ? SliverGrid(
                delegate: SliverChildListDelegate(tiles),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 520,
                  mainAxisExtent: 76,
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
}

class _Header extends StatelessWidget {
  const _Header({required this.vm});
  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final d = parseDateKey(vm.selectedDate);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: d,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) vm.selectDate(dateKey(picked));
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text('${d.year}년 ${d.month}월 ${d.day}일',
                  maxLines: 1,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            ),
          ),
          const Icon(Icons.expand_more, size: 20),
          const Spacer(),
          if (vm.selectedDate != vm.today)
            TextButton(onPressed: vm.goToday, child: const Text('오늘')),
          ActionChip(
            avatar: const Icon(Icons.layers_outlined, size: 16),
            // 모드 이름이 길어도 오른쪽 메뉴 버튼이 화면 밖으로 밀리지 않게 폭을 제한한다
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 72),
              child: Text(vm.activeMode.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            onPressed: () => showModesSheet(context),
          ),
          const SizedBox(width: 4),
          FilterChip(
            avatar: const Text('🌴'),
            label: const Text('쉼'),
            selected: vm.isRestDay,
            onSelected: (v) async {
              await vm.setRest(v);
              if (context.mounted) showToast(context, v ? '쉬는 날로 표시했어요. 실패로 세지 않아요' : '쉼을 해제했어요');
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'range') {
                final r = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  helpText: '쉬는 기간 선택',
                );
                if (r != null && context.mounted) {
                  await vm.setRestRange(dateKey(r.start), dateKey(r.end));
                  if (context.mounted) showToast(context, '선택한 기간을 쉬는 날로 표시했어요');
                }
              }
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'range', child: Text('기간으로 쉬기(휴가)'))],
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.vm});
  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          for (final c in vm.weekCells)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => vm.selectDate(c.date),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: c.selected ? const Color(0xFF5C6166) : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(c.weekdayLabel,
                          style: TextStyle(fontSize: 12, color: c.selected ? Colors.white : cs.outline)),
                      const SizedBox(height: 4),
                      TrafficDot(light: c.light, label: '${c.day}', outlined: c.isToday),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.vm});
  final HomeViewModel vm;

  /// 지금 보고 있는 탭(매일/주간)의 루틴을 여러 개 골라 한 번에 지우는 화면을 연다.
  void _openManage(BuildContext context) {
    final weekly = vm.tab == HomeTab.weekly;
    openBulkDelete(
      context,
      title: weekly ? '주간 루틴 관리' : '매일 루틴 관리',
      emptyText: weekly ? '주간 루틴이 없어요' : '매일 루틴이 없어요',
      changes: vm,
      items: () => [
        for (final h in weekly ? vm.manageWeeklyHabits : vm.manageDailyHabits)
          ManageItem(id: h.id, title: h.name, leading: h.emoji, subtitle: _habitSubtitle(h)),
      ],
      onDelete: vm.deleteHabits,
    );
  }

  static String _habitSubtitle(Habit h) {
    if (h.repeat.type == RepeatType.weekly) return '주 ${h.repeat.times}회';
    return [if (h.time.isNotEmpty) h.time, if (h.context.isNotEmpty) h.context].join('  ');
  }

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, HomeTab t) {
      final on = vm.tab == t;
      return InkWell(
        onTap: () => vm.setTab(t),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          margin: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(width: 3, color: on ? AppColors.darkGreen : Colors.transparent)),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: on ? FontWeight.w900 : FontWeight.w500,
                color: on ? AppColors.darkGreen : Theme.of(context).colorScheme.outline,
              )),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        tab('매일 루틴', HomeTab.routine),
        tab('주간 루틴', HomeTab.weekly),
        tab('회고', HomeTab.review),
        const Spacer(),
        if (vm.tab != HomeTab.review)
          TextButton.icon(
            icon: const Icon(Icons.checklist_rtl, size: 18),
            label: const Text('관리'),
            onPressed: () => _openManage(context),
          ),
      ]),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.vm});
  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forLight(vm.dayLight);
    return Card(
      margin: const EdgeInsets.only(top: 10, bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Text(vm.isRestDay ? '🌴 쉬는 날' : '${vm.percent}%',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(width: 12),
            Expanded(child: ProgressBar(value: vm.isRestDay ? 0 : (vm.dayStat.rate ?? 0), color: color)),
            const SizedBox(width: 12),
            Text('🔥 ${vm.streak}일', style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.vm});
  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SegmentedButton<HomeViewMode>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: HomeViewMode.day, label: Text('일간')),
              ButtonSegment(value: HomeViewMode.week, label: Text('한 주')),
            ],
            selected: {vm.viewMode},
            onSelectionChanged: (s) => vm.setViewMode(s.first),
          ),
          const Spacer(),
          if (vm.viewMode == HomeViewMode.day) ...[
            FilterChip(
              avatar: const Icon(Icons.schedule, size: 16),
              label: const Text('시간순'),
              selected: vm.sortByTime,
              onSelected: (_) => vm.toggleSortByTime(),
            ),
            const SizedBox(width: 6),
            FilterChip(
              label: Text(vm.editing ? '완료' : '편집'),
              selected: vm.editing,
              onSelected: (_) => vm.toggleEditing(),
            ),
            const SizedBox(width: 6),
            ActionChip(label: Text('필터: ${vm.filter.label}'), onPressed: vm.cycleFilter),
          ],
        ],
      ),
    );
  }
}
