import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/journal_repository.dart';
import '../view_models/goals_view_model.dart';
import 'goals_screen.dart';

/// 계획 탭 진입점: ViewModel을 만들어 화면에 연결한다.
class GoalsScreenEntry extends StatelessWidget {
  const GoalsScreenEntry({super.key, required this.journal});
  final JournalRepository journal;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => GoalsViewModel(journal),
        child: const GoalsScreen(),
      );
}
