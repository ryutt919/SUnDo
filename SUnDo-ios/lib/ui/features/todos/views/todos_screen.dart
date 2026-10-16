import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/journal_models.dart';
import '../../../core/app_theme.dart';
import '../../habit_form/views/add_menu_sheet.dart';
import '../view_models/todos_view_model.dart';

/// 투두 탭. 맨 위 입력칸에 쓰고 엔터를 누르면 오늘 할 일로 바로 추가된다.
class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit(TodosViewModel vm) async {
    final text = _ctrl.text;
    if (text.trim().isEmpty) return;
    _ctrl.clear();
    await vm.quickAdd(text);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TodosViewModel>();
    final cs = Theme.of(context).colorScheme;
    final empty = vm.overdue.isEmpty && vm.todayOpen.isEmpty && vm.upcoming.isEmpty && vm.done.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text('투두 (남은 ${vm.openCount}개)'),
        actions: [
          if (vm.done.isNotEmpty)
            TextButton(
              onPressed: () => vm.clearDone(),
              child: const Text('완료 지우기'),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              TextField(
                controller: _ctrl,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(vm),
                decoration: InputDecoration(
                  hintText: '오늘 할 일을 쓰고 엔터',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  suffixIcon: IconButton(icon: const Icon(Icons.add_circle), onPressed: () => _submit(vm)),
                ),
              ),
              if (empty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Center(child: Text('투두가 없어요', style: TextStyle(color: cs.outline))),
                ),
              _Section(title: '지난 미완료', todos: vm.overdue, vm: vm, showDate: true, canMove: true),
              _Section(title: '오늘', todos: vm.todayOpen, vm: vm),
              _Section(title: '예정', todos: vm.upcoming, vm: vm, showDate: true),
              _Section(title: '완료', todos: vm.done, vm: vm, showDate: true),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTodoDialog(context, vm.today),
        icon: const Icon(Icons.event),
        label: const Text('날짜 지정 추가'),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.todos, required this.vm, this.showDate = false, this.canMove = false});
  final String title;
  final List<Todo> todos;
  final TodosViewModel vm;
  final bool showDate;
  final bool canMove;

  @override
  Widget build(BuildContext context) {
    if (todos.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 0, 6),
          child: Text('$title ${todos.length}', style: TextStyle(fontWeight: FontWeight.w700, color: cs.outline)),
        ),
        for (final t in todos)
          Dismissible(
            key: ValueKey('todo-${t.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: AppColors.red,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) => vm.delete(t),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Checkbox(value: t.done, onChanged: (_) => vm.toggle(t), activeColor: AppColors.green),
              title: Text(
                t.text,
                style: TextStyle(decoration: t.done ? TextDecoration.lineThrough : null, color: t.done ? cs.outline : null),
              ),
              subtitle: showDate ? Text(t.date) : null,
              trailing: canMove
                  ? IconButton(
                      tooltip: '오늘로 옮기기',
                      icon: const Icon(Icons.today),
                      onPressed: () => vm.moveToToday(t),
                    )
                  : null,
              onTap: () => showTodoDialog(context, t.date, existing: t),
            ),
          ),
      ],
    );
  }
}
