import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_routine/data/repositories/journal_repository.dart';
import 'package:my_routine/data/services/storage_service.dart';
import 'package:my_routine/domain/models/date_key.dart';
import 'package:my_routine/ui/features/todos/view_models/todos_view_model.dart';
import 'package:my_routine/ui/features/todos/views/todos_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<JournalRepository> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final store = await StorageService.create();
  final journal = JournalRepository(store);
  await journal.load();
  await tester.pumpWidget(
    ChangeNotifierProvider<JournalRepository>.value(
      value: journal,
      child: ChangeNotifierProvider(
        create: (_) => TodosViewModel(journal),
        child: const MaterialApp(home: TodosScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return journal;
}

const _addTime = '시간 추가 (없으면 종일)';

Future<void> _openAdd(WidgetTester tester) async {
  await tester.tap(find.text('추가하기'));
  await tester.pumpAndSettle();
}

Future<void> _confirmPicker(WidgetTester tester) async {
  await tester.tap(find.text('OK').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('입력칸은 없고 "추가하기" 버튼으로 내용, 날짜, 시간을 눌러 추가한다', (tester) async {
    final journal = await _pump(tester);
    expect(find.byType(TextField), findsNothing, reason: '위쪽 입력칸 제거');
    expect(find.text('추가하기'), findsOneWidget);
    expect(find.text('관리'), findsNothing, reason: '투두가 없으면 관리 버튼도 없다');

    await _openAdd(tester);
    expect(find.text('투두 추가'), findsOneWidget);
    expect(find.text(todayKey()), findsOneWidget, reason: '날짜 기본값은 오늘');
    expect(find.text(_addTime), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '치과 예약');
    await tester.tap(find.text(todayKey()));
    await tester.pumpAndSettle();
    await _confirmPicker(tester);
    expect(find.text(todayKey()), findsOneWidget);

    await tester.tap(find.text(_addTime));
    await tester.pumpAndSettle();
    await _confirmPicker(tester);
    expect(find.byTooltip('시간 지우기(종일)'), findsOneWidget);

    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    expect(journal.todos.single.text, '치과 예약');
    expect(journal.todos.single.date, todayKey());
    expect(journal.todos.single.hasTime, isTrue);
    expect(find.text('치과 예약'), findsOneWidget);
  });

  testWidgets('날짜와 시간을 안 고르면 오늘 종일로 저장된다', (tester) async {
    final journal = await _pump(tester);
    await _openAdd(tester);
    await tester.enterText(find.byType(TextFormField), '장보기');
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    expect(journal.todos.single.date, todayKey());
    expect(journal.todos.single.time, '');
  });

  testWidgets('"관리"에서 여러 개를 골라 한 번에 삭제한다', (tester) async {
    final journal = await _pump(tester);
    await journal.addTodo('가', todayKey());
    await journal.addTodo('나', todayKey());
    await journal.addTodo('다', todayKey(), time: '10:00');
    await tester.pumpAndSettle();

    await tester.tap(find.text('관리'));
    await tester.pumpAndSettle();
    expect(find.text('투두 관리'), findsOneWidget);
    expect(find.text('삭제할 항목을 고르세요'), findsOneWidget);

    await tester.tap(find.text('가'));
    await tester.tap(find.text('다'));
    await tester.pumpAndSettle();
    expect(find.text('선택 삭제 (2)'), findsOneWidget);

    await tester.tap(find.text('선택 삭제 (2)'));
    await tester.pumpAndSettle();
    expect(find.text('2개를 삭제할까요?'), findsOneWidget);
    await tester.tap(find.text('삭제').last);
    await tester.pumpAndSettle();

    expect(journal.todos.map((t) => t.text), ['나']);
  });

  testWidgets('삭제 확인에서 취소하면 아무것도 지우지 않는다', (tester) async {
    final journal = await _pump(tester);
    await journal.addTodo('가', todayKey());
    await tester.pumpAndSettle();
    await tester.tap(find.text('관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택 삭제 (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(journal.todos.length, 1);
  });
}
