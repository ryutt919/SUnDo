/// 위젯의 "+" 버튼이 앱을 열 때 넘기는 주소(`myroutine://add?kind=todo|routine`)를 해석한다.
enum WidgetAddTarget { todo, routine }

WidgetAddTarget? parseWidgetLink(Uri? uri) {
  if (uri == null || uri.scheme != 'myroutine' || uri.host != 'add') return null;
  return switch (uri.queryParameters['kind']) {
    'todo' => WidgetAddTarget.todo,
    'routine' => WidgetAddTarget.routine,
    _ => null,
  };
}
