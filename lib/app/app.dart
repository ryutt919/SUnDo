import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/journal_repository.dart';
import '../data/repositories/routine_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/template_repository.dart';
import '../data/services/photo_service.dart';
import '../domain/use_cases/routine_analyzer.dart';
import '../domain/use_cases/stats_use_case.dart';
import '../ui/core/app_theme.dart';
import '../ui/features/shell/app_shell.dart';
import 'app_dependencies.dart';
import 'app_sync.dart';

class MyRoutineApp extends StatefulWidget {
  const MyRoutineApp({super.key, required this.deps});
  final AppDependencies deps;

  @override
  State<MyRoutineApp> createState() => _MyRoutineAppState();
}

class _MyRoutineAppState extends State<MyRoutineApp> with WidgetsBindingObserver {
  late final AppSync _sync = AppSync(widget.deps);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sync.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 위젯에서 체크한 내용(다른 isolate)을 앱으로 돌아올 때 반영한다.
    if (state == AppLifecycleState.resumed) {
      widget.deps.reloadFromDisk().then((_) => _sync.syncNow());
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.deps;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<RoutineRepository>.value(value: d.routine),
        ChangeNotifierProvider<JournalRepository>.value(value: d.journal),
        ChangeNotifierProvider<SettingsRepository>.value(value: d.settings),
        Provider<TemplateRepository>.value(value: d.templates),
        Provider<RoutineAnalyzer>.value(value: d.analyzer),
        Provider<StatsUseCase>.value(value: d.stats),
        Provider<PhotoService>.value(value: d.photos),
      ],
      child: Consumer<SettingsRepository>(
        builder: (_, settings, _) => MaterialApp(
          title: '내 루틴',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: switch (settings.settings.theme) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          },
          home: AppShell(deps: d),
        ),
      ),
    );
  }
}
