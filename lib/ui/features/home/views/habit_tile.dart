import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../view_models/home_view_model.dart';

/// 한 습관 행. 파스텔 배경 위에 번호, 시간/제목, 이모지 체크 버튼이 놓인다.
class HabitTile extends StatelessWidget {
  const HabitTile({
    super.key,
    required this.data,
    required this.editing,
    required this.onToggle,
    required this.onOpen,
    required this.onEdit,
  });

  final HabitRowData data;
  final bool editing;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final h = data.habit;
    const fg = AppColors.rowText;
    return Material(
      color: hexColor(h.color),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: editing ? onEdit : onOpen,
        onLongPress: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text('${data.number}',
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF777777))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(h.time.isNotEmpty ? h.time : (h.context.isNotEmpty ? h.context : '언제든'),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B))),
                    Text('${h.emoji} ${data.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: fg.withValues(alpha: data.done ? 0.6 : 1),
                          decoration: data.done ? TextDecoration.lineThrough : null,
                        )),
                    if (data.subtitle.isNotEmpty)
                      Text(data.subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B6B))),
                  ],
                ),
              ),
              if (editing)
                const Icon(Icons.drag_handle, color: Color(0xFF777777))
              else
                _CheckButton(done: data.done, emoji: h.emoji, onTap: onToggle),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.done, required this.emoji, required this.onTap});
  final bool done;
  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? Colors.white : Colors.white.withValues(alpha: 0.7),
          border: Border.all(color: AppColors.green, width: 2),
          boxShadow: done ? [BoxShadow(color: AppColors.green.withValues(alpha: 0.3), spreadRadius: 3)] : null,
        ),
        child: done ? Text(emoji, style: const TextStyle(fontSize: 24)) : null,
      ),
    );
  }
}

class TodoTile extends StatelessWidget {
  const TodoTile({super.key, required this.data, required this.onToggle, required this.onEdit});
  final TodoRowData data;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = data.todo;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onEdit,
      child: Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray),
        color: cs.surface,
      ),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text('TODO', style: TextStyle(fontSize: 8, color: cs.outline))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.carriedFrom != null ? '${data.carriedFrom!.substring(5)} 에서 이월' : '투두',
                    style: TextStyle(fontSize: 12, color: cs.outline)),
                Text(t.text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      decoration: t.done ? TextDecoration.lineThrough : null,
                    )),
              ],
            ),
          ),
          IconButton(
            onPressed: onToggle,
            icon: Icon(t.done ? Icons.check_box : Icons.check_box_outline_blank, color: AppColors.green, size: 30),
          ),
        ],
      ),
      ),
    );
  }
}
