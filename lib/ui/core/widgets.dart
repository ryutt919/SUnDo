import 'package:flutter/material.dart';

import '../../domain/use_cases/routine_analyzer.dart';
import 'app_theme.dart';

/// 신호등 원. 날짜 숫자를 안에 보여 준다.
class TrafficDot extends StatelessWidget {
  const TrafficDot({super.key, required this.light, required this.label, this.size = 30, this.outlined = false});

  final TrafficLight light;
  final String label;
  final double size;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.forLight(light),
        shape: BoxShape.circle,
        border: outlined ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2) : null,
      ),
      child: Text(label,
          style: TextStyle(color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.w700)),
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.color = AppColors.green});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1).toDouble(),
          minHeight: 8,
          color: color,
          backgroundColor: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
        child: Text(text,
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline)),
      );
}

class EmptyHint extends StatelessWidget {
  const EmptyHint(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.outline, height: 1.6)),
        ),
      );
}

void showToast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
}

Future<bool> confirmDialog(BuildContext context, String message, {String ok = '확인'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> promptDialog(BuildContext context, String title, {String initial = ''}) async {
  final ctrl = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('확인')),
      ],
    ),
  );
  ctrl.dispose();
  return (r == null || r.isEmpty) ? null : r;
}
