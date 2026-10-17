import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_routine/main.dart' as app;
import 'package:my_routine/ui/features/stats/view_models/stats_view_model.dart' show StatsCalendarTab;

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
    await tester.scrollUntilVisible(find.textContaining('월 캘린더'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('월 캘린더'), findsOneWidget);
    expect(find.textContaining('날짜가 잡힌 투두'), findsOneWidget, reason: '처음에는 투두 캘린더 탭');
    Finder tab(String label) => find.descendant(of: find.byType(SegmentedButton<StatsCalendarTab>), matching: find.text(label));
    await tester.ensureVisible(tab('계획'));
    await tester.pumpAndSettle();
    await tester.tap(tab('계획'));
    await tester.pumpAndSettle();
    expect(find.textContaining('월간 계획'), findsOneWidget);
    await tester.ensureVisible(tab('무드'));
    await tester.pumpAndSettle();
    await tester.tap(tab('무드'));
    await tester.pumpAndSettle();
    expect(find.textContaining('월간 계획'), findsNothing);
    expect(find.textContaining('날짜가 잡힌 투두'), findsNothing);
  });

  testWidgets('위젯 "+" 링크: 투두 위젯은 투두 추가 창, 오늘의 루틴 위젯은 새 루틴 화면을 연다', (tester) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // iOS 위젯의 "+"(Link)가 앱을 열 때 home_widget 플러그인이 Dart로 보내는 이벤트를 그대로 흉내 낸다
    Future<void> widgetLink(String url) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'home_widget/updates',
        const StandardMethodCodec().encodeSuccessEnvelope(url),
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    await widgetLink('myroutine://add?kind=todo&homeWidget');
    expect(find.text('투두 추가'), findsOneWidget, reason: '투두 위젯 "+" 는 투두 추가 창');
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    await widgetLink('myroutine://add?kind=routine&homeWidget');
    expect(find.text('새 루틴'), findsOneWidget, reason: '오늘의 루틴 위젯 "+" 는 새 루틴 화면');
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await widgetLink('myroutine://open?homeWidget');
    expect(find.text('투두 추가'), findsNothing);
    expect(find.text('새 루틴'), findsNothing, reason: '그냥 열기 링크는 추가 화면을 열지 않는다');
  });
}
