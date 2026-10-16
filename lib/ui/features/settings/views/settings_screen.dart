import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/calendar_repository.dart';
import '../../../core/widgets.dart';
import '../../home/views/modes_sheet.dart';
import '../view_models/settings_view_model.dart';

/// 시각을 고르는 알람 설정 줄. 값이 비어 있으면 꺼진 상태다.
class _AlarmTile extends StatelessWidget {
  const _AlarmTile({required this.title, required this.subtitle, required this.value, required this.onChanged});
  final String title;
  final String subtitle;
  final String value;
  final Future<void> Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(value.isEmpty ? '꺼짐' : '$value  $subtitle'),
      trailing: value.isEmpty
          ? const Icon(Icons.schedule)
          : IconButton(icon: const Icon(Icons.close), onPressed: () => onChanged('')),
      onTap: () async {
        final p = value.split(':');
        final initial = p.length == 2 ? TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])) : TimeOfDay.now();
        final t = await showTimePicker(context: context, initialTime: initial);
        if (t != null) await onChanged('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
      },
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('설정', style: TextStyle(fontWeight: FontWeight.w900))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                const SectionTitle('화면'),
                ListTile(
                  title: const Text('화면 테마'),
                  trailing: DropdownButton<String>(
                    value: vm.settings.theme,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'auto', child: Text('시스템')),
                      DropdownMenuItem(value: 'light', child: Text('라이트')),
                      DropdownMenuItem(value: 'dark', child: Text('다크')),
                    ],
                    onChanged: (v) => v == null ? null : vm.setTheme(v),
                  ),
                ),
                SwitchListTile(
                  title: const Text('완료 항목을 아래로'),
                  subtitle: const Text('체크하면 목록 맨 아래로 내려가요'),
                  value: vm.settings.doneToBottom,
                  onChanged: vm.setDoneToBottom,
                ),
                ListTile(
                  title: const Text('루틴 모드'),
                  subtitle: Text('${vm.modeCount}개. 홈 상단에서도 바로 바꿀 수 있어요'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showModesSheet(context),
                ),
                const SectionTitle('알림과 위젯'),
                ListTile(
                  title: const Text('루틴 알람'),
                  subtitle: Text(vm.notificationsOn ? '알림이 켜져 있어요' : '알림 권한이 꺼져 있어요'),
                  trailing: vm.notificationsOn
                      ? TextButton(onPressed: vm.sendTestNotification, child: const Text('테스트'))
                      : FilledButton.tonal(
                          onPressed: () async {
                            final ok = await vm.requestNotifications();
                            if (context.mounted) showToast(context, ok ? '알림을 허용했어요' : '알림이 허용되지 않았어요. 앱 설정에서 켤 수 있어요');
                          },
                          child: const Text('허용하기'),
                        ),
                ),
                _AlarmTile(
                  title: '아침 알람',
                  subtitle: '오늘의 루틴을 알려 줘요',
                  value: vm.settings.morningAlarm,
                  onChanged: vm.setMorningAlarm,
                ),
                _AlarmTile(
                  title: '저녁 알람',
                  subtitle: '루틴 확인과 회고를 권해요',
                  value: vm.settings.eveningAlarm,
                  onChanged: vm.setEveningAlarm,
                ),
                ListTile(
                  title: const Text('홈 화면 위젯 추가'),
                  subtitle: const Text('오늘의 루틴과 투두(체크 가능), 주간, 월간 신호등 위젯이 있어요'),
                  trailing: const Icon(Icons.widgets_outlined),
                  onTap: () => _widgetSheet(context, vm),
                ),
                const SectionTitle('캘린더'),
                ListTile(
                  title: const Text('투두를 캘린더에 연동'),
                  subtitle: Text(vm.calendarOn
                      ? '${vm.calendarName}과 동기화 중 (${vm.calendarLinked}개)'
                      : '투두를 기기 캘린더 일정과 양방향으로 맞춰요. 구글/삼성 캘린더 계정과 동기화돼요'),
                  trailing: Switch(value: vm.calendarOn, onChanged: (v) => _toggleCalendar(context, vm, v)),
                  onTap: () => _toggleCalendar(context, vm, !vm.calendarOn),
                ),
                if (vm.calendarOn) ...[
                  SwitchListTile(
                    title: const Text('캘린더에서 바꾼 내용을 투두에 반영'),
                    subtitle: const Text('제목, 날짜, 완료 표시(제목 앞 ✔), 일정 삭제가 투두에도 적용돼요. 일정을 지우면 투두도 지워져요'),
                    value: vm.calendarPull,
                    onChanged: vm.setCalendarPull,
                  ),
                  SwitchListTile(
                    title: const Text('캘린더의 새 일정을 투두로 가져오기'),
                    subtitle: const Text('오늘부터 60일 안의 반복되지 않는 일정을 투두로 만들어요. 캘린더 일정은 지우거나 옮기지 않아요'),
                    value: vm.calendarImport,
                    onChanged: vm.setCalendarImport,
                  ),
                  ListTile(
                    title: const Text('지금 동기화'),
                    subtitle: const Text('앱을 열 때와 투두를 바꿀 때 자동으로 맞춰요'),
                    trailing: const Icon(Icons.sync),
                    onTap: () async {
                      await vm.syncCalendarNow();
                      if (context.mounted) showToast(context, '캘린더와 맞췄어요');
                    },
                  ),
                  ListTile(
                    title: const Text('캘린더에서 TDnR 일정 모두 지우기'),
                    subtitle: const Text('연동은 유지돼요. 다음 동기화 때 다시 만들어져요'),
                    trailing: const Icon(Icons.delete_sweep_outlined),
                    onTap: () async {
                      if (!await confirmDialog(context, 'TDnR이 만든 캘린더 일정을 모두 지울까요?', ok: '지우기')) return;
                      await vm.removeCalendarEvents();
                      if (context.mounted) showToast(context, '지웠어요');
                    },
                  ),
                ],
                const SectionTitle('데이터'),
                ListTile(
                  title: const Text('백업 내보내기'),
                  subtitle: const Text('JSON 파일로 공유/저장'),
                  trailing: const Icon(Icons.ios_share),
                  onTap: () async {
                    try {
                      await vm.exportBackup();
                    } on Exception catch (e) {
                      if (context.mounted) showToast(context, '내보내지 못했어요: $e');
                    }
                  },
                ),
                ListTile(
                  title: const Text('백업 불러오기'),
                  subtitle: const Text('웹앱 백업 파일도 불러올 수 있어요. 현재 데이터를 덮어써요'),
                  trailing: const Icon(Icons.file_open_outlined),
                  onTap: () async {
                    if (!await confirmDialog(context, '현재 데이터를 선택한 백업으로 덮어쓸까요?', ok: '불러오기')) return;
                    try {
                      final ok = await vm.importBackup();
                      if (context.mounted && ok) showToast(context, '불러왔어요');
                    } on FormatException catch (e) {
                      if (context.mounted) showToast(context, e.message);
                    }
                  },
                ),
                ListTile(
                  title: const Text('보관된 루틴'),
                  subtitle: Text('${vm.archived.length}개'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _archivedSheet(context),
                ),
                ListTile(
                  title: Text('모든 데이터 지우기', style: TextStyle(color: cs.error)),
                  onTap: () async {
                    if (await confirmDialog(context, '모든 루틴, 기록, 회고가 삭제돼요. 계속할까요?', ok: '지우기') &&
                        context.mounted &&
                        await confirmDialog(context, '정말 지울까요? 되돌릴 수 없어요.', ok: '지우기')) {
                      await vm.wipe();
                      if (context.mounted) showToast(context, '초기화했어요');
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('데이터는 이 기기에만 저장돼요. 서버로 전송되지 않아요.',
                      style: TextStyle(fontSize: 12, color: cs.outline)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleCalendar(BuildContext context, SettingsViewModel vm, bool on) async {
    if (!on) {
      await vm.disableCalendar();
      return;
    }
    final choices = await vm.loadCalendarChoices();
    if (!context.mounted) return;
    if (choices == null) {
      showToast(context, '캘린더 권한이 필요해요. 앱 설정에서 허용해 주세요');
      return;
    }
    if (choices.isEmpty) {
      showToast(context, '쓸 수 있는 캘린더가 없어요. 캘린더 앱에서 계정을 먼저 추가해 주세요');
      return;
    }
    final picked = await showModalBottomSheet<CalendarChoice>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('어느 캘린더에 만들까요?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            for (final ch in choices)
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: Text(ch.name),
                subtitle: ch.account.isEmpty ? null : Text(ch.account),
                trailing: ch.isPrimary ? const Text('기본') : null,
                onTap: () => Navigator.pop(c, ch),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await vm.enableCalendar(picked);
  }

  void _widgetSheet(BuildContext context, SettingsViewModel vm) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: FutureBuilder<bool>(
          future: vm.canPinWidget,
          builder: (_, snap) {
            final canPin = snap.data ?? false;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('홈 화면 위젯', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('홈 화면 빈 곳을 길게 눌러 "위젯"에서 "TDnR"을 고르거나, 아래 버튼으로 바로 추가하세요.\n'
                    '오늘의 루틴 위젯은 이모지 칸을 눌러 앱을 열지 않고 체크할 수 있어요.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: canPin ? () { vm.pinTodayWidget(); Navigator.pop(sheetContext); } : null,
                  icon: const Icon(Icons.checklist),
                  label: const Text('오늘의 루틴 위젯 추가'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: canPin ? () { vm.pinTodoWidget(); Navigator.pop(sheetContext); } : null,
                  icon: const Icon(Icons.task_alt),
                  label: const Text('투두 위젯 추가'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: canPin ? () { vm.pinWeekWidget(); Navigator.pop(sheetContext); } : null,
                  icon: const Icon(Icons.traffic),
                  label: const Text('주간 신호등 위젯 추가'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: canPin ? () { vm.pinMonthWidget(); Navigator.pop(sheetContext); } : null,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('월간 신호등 위젯 추가'),
                ),
                if (!canPin)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('이 런처는 바로 추가를 지원하지 않아요. 홈 화면을 길게 눌러 위젯 목록에서 추가해 주세요.'),
                  ),
              ]),
            );
          },
        ),
      ),
    );
  }

  void _archivedSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<SettingsViewModel>(),
        child: Consumer<SettingsViewModel>(
          builder: (c, vm, _) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('보관된 루틴', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                if (vm.archived.isEmpty) const EmptyHint('보관된 루틴이 없어요.'),
                for (final h in vm.archived)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${h.emoji} ${h.name}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton(onPressed: () => vm.restore(h.id), child: const Text('복원')),
                      TextButton(
                        onPressed: () async {
                          if (await confirmDialog(c, '기록까지 영구 삭제할까요?', ok: '삭제')) await vm.purge(h.id);
                        },
                        child: const Text('영구 삭제'),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
