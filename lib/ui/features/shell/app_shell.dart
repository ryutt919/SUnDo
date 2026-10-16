import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_dependencies.dart';
import '../goals/views/goals_screen_entry.dart';
import '../home/view_models/home_view_model.dart';
import '../home/views/home_screen.dart';
import '../settings/view_models/settings_view_model.dart';
import '../settings/views/settings_screen.dart';
import '../stats/view_models/stats_view_model.dart';
import '../stats/views/stats_screen.dart';

/// 하단 탭(넓은 화면에서는 왼쪽 레일)으로 홈, 계획, 통계, 설정을 오간다.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.deps});
  final AppDependencies deps;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _items = [
    (Icons.home_outlined, Icons.home, '홈'),
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
