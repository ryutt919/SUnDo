import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/journal_repository.dart';
import '../../../../data/repositories/routine_repository.dart';
import '../../../../domain/models/journal_models.dart';
import '../../../../domain/use_cases/routine_analyzer.dart';
import '../../../core/app_theme.dart';
import '../view_models/review_view_model.dart';

const moodEmojis = ['😭', '😟', '😐', '🙂', '😄'];

class ReviewView extends StatelessWidget {
  const ReviewView({super.key, required this.date});
  final String date;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => ReviewViewModel(
        journal: c.read<JournalRepository>(),
        routine: c.read<RoutineRepository>(),
        analyzer: c.read<RoutineAnalyzer>(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _ReviewBody(date: date),
      ),
    );
  }
}

class _ReviewBody extends StatefulWidget {
  const _ReviewBody({required this.date});
  final String date;

  @override
  State<_ReviewBody> createState() => _ReviewBodyState();
}

class _ReviewBodyState extends State<_ReviewBody> {
  late final TextEditingController _best = TextEditingController();
  late final TextEditingController _msg = TextEditingController();
  late final TextEditingController _wBest = TextEditingController();
  late final TextEditingController _wMsg = TextEditingController();
  String? _loadedFor;

  void _syncControllers(ReviewViewModel vm) {
    if (_loadedFor == widget.date) return;
    _loadedFor = widget.date;
    final r = vm.reviewOf(widget.date);
    final w = vm.weekReviewOf(widget.date);
    _best.text = r.best;
    _msg.text = r.msg;
    _wBest.text = w.best;
    _wMsg.text = w.msg;
  }

  @override
  void dispose() {
    _best.dispose();
    _msg.dispose();
    _wBest.dispose();
    _wMsg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReviewViewModel>();
    _syncControllers(vm);
    final r = vm.reviewOf(widget.date);
    final st = vm.statOf(widget.date);
    final memos = vm.memosOf(widget.date);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Card(
          title: '오늘의 기분',
          child: Row(children: [
            for (var i = 0; i < moodEmojis.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(color: r.mood == i + 1 ? AppColors.green : cs.outlineVariant, width: r.mood == i + 1 ? 2 : 1),
                      backgroundColor: r.mood == i + 1 ? AppColors.green.withValues(alpha: 0.12) : null,
                    ),
                    onPressed: () => vm.setMood(widget.date, i + 1),
                    child: Text(moodEmojis[i], style: const TextStyle(fontSize: 24)),
                  ),
                ),
              ),
          ]),
        ),
        _Card(
          title: '데일리 회고',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _best,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: '오늘 가장 좋았던 일'),
              onChanged: (v) => vm.setBest(widget.date, v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _msg,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: '나에게 한마디'),
              onChanged: (v) => vm.setMsg(widget.date, v),
            ),
            const SizedBox(height: 8),
            Text('오늘 루틴 달성: ${st.rest ? '쉼' : '${st.done}/${st.due}'}', style: TextStyle(fontSize: 12, color: cs.outline)),
          ]),
        ),
        _Card(
          title: '주차 루틴 회고',
          child: Column(children: [
            TextField(
              controller: _wBest,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: '이번 주 잘한 점'),
              onChanged: (v) => vm.setWeekBest(widget.date, v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _wMsg,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: '다음 주에 바꿀 점'),
              onChanged: (v) => vm.setWeekMsg(widget.date, v),
            ),
          ]),
        ),
        _Card(
          title: '메모',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (memos.isEmpty) Text('아직 메모가 없어요.', style: TextStyle(color: cs.outline, fontSize: 13)),
            for (final m in memos)
              InkWell(
                onTap: () => _memoDialog(context, vm, existing: m),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: m.hl ? const Color(0xFFFFF3A8) : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: const Border(left: BorderSide(color: AppColors.yellow, width: 3)),
                  ),
                  child: Text('${m.kind == MemoKind.long ? '📝' : '💬'} ${m.text}',
                      style: TextStyle(color: m.hl ? AppColors.rowText : null)),
                ),
              ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => _memoDialog(context, vm, kind: MemoKind.short), child: const Text('짧은 메모'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => _memoDialog(context, vm, kind: MemoKind.long), child: const Text('긴 메모'))),
            ]),
          ]),
        ),
      ],
    );
  }

  Future<void> _memoDialog(BuildContext context, ReviewViewModel vm, {Memo? existing, MemoKind kind = MemoKind.short}) async {
    final k = existing?.kind ?? kind;
    final ctrl = TextEditingController(text: existing?.text ?? '');
    var hl = existing?.hl ?? false;
    await showDialog<void>(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (_, setState) => AlertDialog(
          title: Text(k == MemoKind.long ? '긴 메모' : '짧은 메모'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: ctrl, autofocus: true, minLines: k == MemoKind.long ? 8 : 3, maxLines: k == MemoKind.long ? 14 : 6),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: hl,
              onChanged: (v) => setState(() => hl = v ?? false),
              title: const Text('형광펜 표시'),
            ),
          ]),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  await vm.deleteMemo(existing.id);
                  if (dc.mounted) Navigator.pop(dc);
                },
                child: const Text('삭제'),
              ),
            TextButton(onPressed: () => Navigator.pop(dc), child: const Text('취소')),
            TextButton(
              onPressed: () async {
                final text = ctrl.text.trim();
                if (text.isEmpty) return;
                await vm.saveMemo(id: existing?.id, date: widget.date, kind: k, text: text, hl: hl);
                if (dc.mounted) Navigator.pop(dc);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            child,
          ]),
        ),
      );
}
