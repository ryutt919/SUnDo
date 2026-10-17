import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

import '../../../app/app_dependencies.dart';
import '../../../app/widget_link.dart';
import '../../../domain/models/date_key.dart';
import '../goals/views/goals_screen_entry.dart';
import '../habit_form/views/add_menu_sheet.dart';
import '../habit_form/views/habit_form_screen.dart';
import '../home/view_models/home_view_model.dart';
import '../home/views/home_screen.dart';
import '../settings/view_models/settings_view_model.dart';
import '../settings/views/settings_screen.dart';
import '../stats/view_models/stats_view_model.dart';
import '../stats/views/stats_screen.dart';
import '../todos/view_models/todos_view_model.dart';
import '../todos/views/todos_screen.dart';

/// 하단 탭(넓은 화면에서는 왼쪽 레일)으로 홈, 투두, 계획, 통계, 설정을 오간다.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.deps});
  final AppDependencies deps;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  StreamSubscription<Uri?>? _linkSub;

  @override
  void initState() {
    super.initState();
    // 위젯의 "+" 버튼으로 앱이 열리면(꺼져 있던 경우와 켜져 있던 경우 모두) 해당 추가 화면을 연다.
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_onWidgetLink);
    _linkSub = HomeWidget.widgetClicked.listen(_onWidgetLink);
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  void _onWidgetLink(Uri? uri) {
    final target = parseWidgetLink(uri);
    if (target == null) return;
    // 첫 화면이 그려진 뒤에 대화상자나 화면을 연다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (target) {
        case WidgetAddTarget.todo:
          setState(() => _index = 1);
          showTodoDialog(context, todayKey());
        case WidgetAddTarget.routine:
          setState(() => _index = 0);
          openHabitForm(context);
      }
    });
  }

  static const _items = [
    (Icons.home_outlined, Icons.home, '홈'),
    (Icons.checklist_outlined, Icons.checklist, '투두'),
    (Icons.flag_outlined, Icons.flag, '계획'),
    (Icons.bar_chart_outlined, Icons.bar_chart, '통계'),
    (Icons.settings_outlined, Icons.settings, '설정'),
  ];

  @override
  Widget build(BuildContext context) {
    final d = widget.deps;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => HomeViewModel(routine: d.routine, journal: d.journal, settings: d.settings, analyzer: d.analyzer),
        ),
        ChangeNotifierProvider(create: (_) => TodosViewModel(d.journal)),
        ChangeNotifierProvider(
          create: (_) => StatsViewModel(routine: d.routine, journal: d.journal, analyzer: d.analyzer, stats: d.stats),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsViewModel(
            settings: d.settings,
            routine: d.routine,
            backup: d.backup,
            notifications: d.notifications,
            widgets: d.widgets,
            calendar: d.calendar,
          ),
        ),
      ],
      child: Scaffold(
        body: Row(
          children: [
            if (wide)
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final it in _items)
                    NavigationRailDestination(icon: Icon(it.$1), selectedIcon: Icon(it.$2), label: Text(it.$3)),
                ],
              ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  const HomeScreen(),
                  const TodosScreen(),
                  GoalsScreenEntry(journal: d.journal),
                  const StatsScreen(),
                  const SettingsScreen(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: [
                  for (final it in _items)
                    NavigationDestination(icon: Icon(it.$1), selectedIcon: Icon(it.$2), label: it.$3),
                ],
              ),
      ),
    );
  }
}
