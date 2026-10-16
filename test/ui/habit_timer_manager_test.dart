import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_routine/ui/core/habit_timer_manager.dart';

import '../test_helpers.dart';

void main() {
  const d = '2026-10-14';

  test('타이머는 시트(ViewModel)와 무관하게 흐르고, 끝나면 습관을 완료로 체크한다', () async {
    final repo = await emptyRoutine();
    await repo.addHabit(habit('a'));
    final timers = HabitTimerManager(repo);

    fakeAsync((async) {
      timers.start('a', d, 1); // 1분
      expect(timers.isRunning('a', d), isTrue);
      async.elapse(const Duration(seconds: 30));
      expect(timers.secondsLeft('a', d), 30);

      // 일시정지하면 멈추고, 다시 시작하면 남은 시간부터 이어진다
      timers.pause('a', d);
      async.elapse(const Duration(seconds: 20));
      expect(timers.secondsLeft('a', d), 30);
      timers.start('a', d, 1);
      async.elapse(const Duration(seconds: 31));
      async.flushMicrotasks();

      expect(timers.isFinished('a', d), isTrue);
      expect(timers.isRunning('a', d), isFalse);
    });
    await Future<void>.delayed(Duration.zero);
    expect(repo.isDone('a', d), isTrue);
  });

  test('끝난 타이머를 다시 시작하면 처음 시간부터 시작한다', () async {
    final repo = await emptyRoutine();
    await repo.addHabit(habit('a'));
    final timers = HabitTimerManager(repo);
    fakeAsync((async) {
      timers.start('a', d, 1);
      async.elapse(const Duration(seconds: 61));
      async.flushMicrotasks();
      expect(timers.isFinished('a', d), isTrue);
      timers.start('a', d, 1);
      expect(timers.secondsLeft('a', d), 60);
      expect(timers.isFinished('a', d), isFalse);
      timers.reset('a', d);
      expect(timers.secondsLeft('a', d), isNull);
    });
  });
}

