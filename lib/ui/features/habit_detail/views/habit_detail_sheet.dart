import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/routine_repository.dart';
import '../../../../data/services/photo_service.dart';
import '../../../../domain/models/habit.dart';
import '../../../../domain/use_cases/routine_analyzer.dart';
import '../../../../domain/use_cases/stats_use_case.dart';
import '../../../core/habit_timer_manager.dart';
import '../../../core/widgets.dart';
import '../../habit_form/views/habit_form_screen.dart';
import '../view_models/habit_detail_view_model.dart';
import 'value_chart.dart';

Future<void> showHabitDetail(BuildContext context, String habitId, String date) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider(
      create: (c) => HabitDetailViewModel(
        routine: c.read<RoutineRepository>(),
        analyzer: c.read<RoutineAnalyzer>(),
        stats: c.read<StatsUseCase>(),
        photos: c.read<PhotoService>(),
        timers: c.read<HabitTimerManager>(),
        habitId: habitId,
        date: date,
      ),
      child: const _HabitDetailSheet(),
    ),
  );
}

class _HabitDetailSheet extends StatelessWidget {
  const _HabitDetailSheet();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HabitDetailViewModel>();
    final h = vm.habit;
    if (h == null) return const SizedBox(height: 120, child: Center(child: Text('습관을 찾을 수 없어요.')));
    final cs = Theme.of(context).colorScheme;
    final log = vm.log;
    final series = vm.valueSeries;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text('${h.emoji} ${h.name}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  Navigator.pop(context);
                  openHabitForm(context, habitId: h.id);
                },
              ),
            ]),
            Text('${vm.date}  ${h.repeat.summary}  연속 ${vm.streak}일',
                style: TextStyle(fontSize: 12, color: cs.outline)),
            if (h.reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('💭 ${h.reason}', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ],
            const SectionTitle('난이도'),
            for (final l in HabitLevel.values)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: log.level == l.name ? cs.primary : cs.outlineVariant),
                ),
                child: ListTile(
                  dense: true,
                  onTap: () => vm.setLevel(l),
                  leading: Text(l.label, style: TextStyle(fontWeight: FontWeight.w900, color: cs.primary)),
                  title: Text(h.levels[l.name]?.isNotEmpty == true ? h.levels[l.name]! : '-'),
                  trailing: log.level == l.name ? Icon(Icons.check_circle, color: cs.primary) : null,
                ),
              ),
            if (h.alts.isNotEmpty) ...[
              const SectionTitle('오늘은 이 이름으로'),
              Wrap(spacing: 6, children: [
                ChoiceChip(label: Text(h.name), selected: log.alt.isEmpty, onSelected: (_) => vm.setAlt('')),
                for (final a in h.alts) ChoiceChip(label: Text(a), selected: log.alt == a, onSelected: (_) => vm.setAlt(a)),
              ]),
            ],
            if (h.unit.isNotEmpty) ...[
              SectionTitle('오늘 기록 (${h.unit})'),
              TextFormField(
                initialValue: log.value == null ? '' : '${log.value}',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: '숫자를 입력'),
                onFieldSubmitted: vm.setValue,
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
              ),
              if (series.length >= 2) ...[
                const SizedBox(height: 10),
                SizedBox(height: 110, child: ValueChart(points: series.map((e) => e.$2).toList())),
                Text('최근 30일 기록', style: TextStyle(fontSize: 11, color: cs.outline)),
              ],
            ],
            if (h.timerMin > 0) ...[
              const SectionTitle('타이머'),
              Center(
                child: Text(_clock(vm.secondsLeft ?? h.timerMin * 60),
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()])),
              ),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    onPressed: vm.timerRunning ? vm.pauseTimer : vm.startTimer,
                    child: Text(vm.timerRunning ? '일시정지' : '시작'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: vm.resetTimer, child: const Text('처음으로'))),
              ]),
              if (vm.timerFinished) const Padding(padding: EdgeInsets.only(top: 6), child: Text('🎉 타이머가 끝나서 완료로 체크했어요')),
            ],
            const SectionTitle('사진 인증'),
            if (log.photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(log.photo!),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 80,
                    alignment: Alignment.center,
                    color: cs.surfaceContainerHighest,
                    child: Text('사진을 불러오지 못했어요', style: TextStyle(color: cs.outline)),
                  ),
                ),
              ),
            Row(children: [
              TextButton.icon(
                onPressed: () => vm.attachPhoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('찍기'),
              ),
              TextButton.icon(
                onPressed: () => vm.attachPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('앨범'),
              ),
              if (log.photo != null)
                TextButton.icon(onPressed: vm.removePhoto, icon: const Icon(Icons.delete_outline), label: const Text('삭제')),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await vm.toggleDone();
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(log.done ? '완료 취소' : '완료로 체크'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _clock(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}
