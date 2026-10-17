import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_routine/main.dart' as app;

/// iOS 시뮬레이터에서 앱을 실제로 띄워 투두 추가(시간 포함), 일괄 삭제, 통계 캘린더를 확인한다.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('투두 추가, 시간 선택, 관리에서 일괄 삭제, 통계 캘린더', (tester) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 투두 탭: 입력칸은 없고 "추가하기" 버튼이 있다
    await tester.tap(find.text('투두'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('추가하기'), findsOneWidget);

    Future<void> addTodo(String text, {bool withTime = false}) async {
      await tester.tap(find.text('추가하기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), text);
      if (withTime) {
        await tester.tap(find.text('시간 추가 (없으면 종일)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK').last);
        await tester.pumpAndSettle();
        expect(find.byTooltip('시간 지우기(종일)'), findsOneWidget);
      }
      await tester.tap(find.text('추가'));
      await tester.pumpAndSettle();
    }

    await addTodo('아이폰 시간 있는 할 일', withTime: true);
    await addTodo('아이폰 종일 할 일');
    expect(find.text('아이폰 시간 있는 할 일'), findsOneWidget);
    expect(find.text('아이폰 종일 할 일'), findsOneWidget);

    // 관리: 두 개를 골라 한 번에 삭제
    await tester.tap(find.text('관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('선택 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제').last);
    await tester.pumpAndSettle();
    expect(find.text('투두가 없어요'), findsOneWidget);
    Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
    await tester.pumpAndSettle();

    // 통계: 투두 캘린더와 계획 캘린더
    await tester.tap(find.text('통계'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('투두 캘린더'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('투두 캘린더'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('계획 캘린더'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('계획 캘린더'), findsOneWidget);
  });
}
