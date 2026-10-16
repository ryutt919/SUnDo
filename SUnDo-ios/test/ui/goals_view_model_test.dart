import 'package:flutter_test/flutter_test.dart';
import 'package:my_routine/data/repositories/journal_repository.dart';
import 'package:my_routine/data/services/storage_service.dart';
import 'package:my_routine/domain/models/journal_models.dart';
import 'package:my_routine/ui/features/goals/view_models/goals_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<({GoalsViewModel vm, JournalRepository journal})> _setup() async {
  SharedPreferences.setMockInitialValues({});
  final journal = JournalRepository(await StorageService.create());
  await journal.load();
  return (vm: GoalsViewModel(journal), journal: journal);
}

Goal _only(GoalsViewModel vm) => vm.goals.single;

void main() {
  test('계획을 완료로 체크하면 진행률이 100%가 되고 세부 항목도 모두 끝난 것으로 본다', () async {
    final s = await _setup();
    await s.vm.addGoal('운동 계획');
    await s.vm.addItem(_only(s.vm), '스트레칭');
    await s.vm.addItem(_only(s.vm), '달리기');
    expect(_only(s.vm).progress, 0);
    await s.vm.toggleGoal(_only(s.vm));
    final g = _only(s.vm);
    expect(g.done, isTrue);
    expect(g.progress, 1);
    expect(g.items.every((i) => i.done), isTrue);
    expect(s.vm.doneGoals.length, 1);
    expect(s.vm.openGoals, isEmpty);
    expect(s.vm.completion, (done: 1, total: 1));
  });

  test('체크를 풀면 계획만 진행 중으로 돌아가고 세부 항목은 그대로다', () async {
    final s = await _setup();
    await s.vm.addGoal('독서');
    await s.vm.addItem(_only(s.vm), '1권');
    await s.vm.toggleGoal(_only(s.vm));
    await s.vm.toggleGoal(_only(s.vm));
    expect(_only(s.vm).done, isFalse);
    expect(_only(s.vm).items.single.done, isTrue);
    expect(s.vm.openGoals.length, 1);
  });

  test('세부 항목을 모두 끝내면 계획이 완료가 되고, 하나를 풀면 진행 중으로 돌아간다', () async {
    final s = await _setup();
    await s.vm.addGoal('이사');
    await s.vm.addItem(_only(s.vm), '짐 싸기');
    await s.vm.addItem(_only(s.vm), '청소');
    await s.vm.toggleItem(_only(s.vm), 0);
    expect(_only(s.vm).done, isFalse);
    await s.vm.toggleItem(_only(s.vm), 1);
    expect(_only(s.vm).done, isTrue);
    await s.vm.toggleItem(_only(s.vm), 0);
    expect(_only(s.vm).done, isFalse);
  });

  test('완료한 계획에 세부 항목을 더하면 다시 진행 중이 되고, 항목 없는 계획은 직접 체크해야 완료다', () async {
    final s = await _setup();
    await s.vm.addGoal('여행');
    await s.vm.toggleGoal(_only(s.vm));
    expect(_only(s.vm).done, isTrue);
    await s.vm.addItem(_only(s.vm), '숙소 예약');
    expect(_only(s.vm).done, isFalse);
  });

  test('전체 진행률에 완료한 계획은 100%로 들어가고, 완료 상태는 저장 후에도 유지된다', () async {
    final s = await _setup();
    await s.vm.addGoal('A');
    await s.vm.addGoal('B');
    await s.vm.toggleGoal(s.vm.goals.first);
    expect(s.vm.overallProgress, 0.5);
    final reloaded = Goal.fromJson(s.vm.doneGoals.single.toJson());
    expect(reloaded.done, isTrue);
    expect(Goal.fromJson({'id': 'x', 'periodKey': '2026-10'}).done, isFalse, reason: '이전 백업에는 done이 없다');
  });
}
