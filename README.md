# TDnR

서버와 로그인 없이 기기 안에서만 동작하는 Android 습관/투두 앱. 홈 화면 위젯에서 앱을 열지 않고 체크하고, 투두는 기기 캘린더와 연동함.

## Motivation

- 기존 루틴 앱의 습관 추적, 신호등 통계, 투두, 회고를 **광고와 결제 제한 없이** 쓰고 싶었음.
- 매번 앱을 여는 비용을 줄이기 위해 **홈 화면 위젯에서 바로 체크**하는 흐름을 목표로 함.
- 소셜, 결제, 계정 동기화는 범위에서 제외함.

## Method

### Architecture

- Flutter 3.47, Dart 3.13. UI(MVVM, `ChangeNotifier`) / Data(service, repository) / Domain(model, use case) 3계층에 `provider`로 의존성을 주입함.
- 저장은 `shared_preferences`의 JSON이며, 위젯과 알람은 같은 저장소를 읽음.
- 위젯은 `home_widget`과 네이티브 Kotlin `AppWidgetProvider`로 구현함. Flutter가 `snapshot` JSON을 쓰면 Kotlin이 `RemoteViews`로 그림.

### Domain Rules

- 달성률 60% 이상 초록, 20% 이상 노랑, 미만 빨강, 쉬는 날 파랑, 오늘 0%는 색 없음.
- 루틴은 **매일 루틴**과 **주간 루틴**으로 나눔. 매일 루틴은 매일, 요일, N일마다, 매월 날짜 반복이고 달성률과 신호등에 들어감.
- 주간 루틴은 루틴마다 주 목표 횟수(1〜7)를 정하고 7일 칸에서 체크함. 달성률에는 넣지 않고 주 단위 진행률로 봄.
- 루틴 모드는 날짜별 이력(`modeFrom`, `modeDeleted`)으로 저장해 과거 통계가 바뀌지 않게 함.

### Widgets

- 오늘의 루틴(매일과 주간), 투두, 주간 신호등, 월간 신호등 4종. 체크 버튼은 64dp이고 위젯 높이에 들어가는 행만 그림.
- 체크는 `myroutine://toggle`, `myroutine://toggletodo` URI를 **백그라운드 Dart isolate**가 처리함.

### Calendar Sync

- 날짜를 정한 투두를 **기기 캘린더(CalendarProvider)에 종일 일정**으로 만들고, 수정과 삭제, 완료(제목 앞 체크 표시)를 따라감.
- 투두별 이벤트 ID와 마지막으로 맞춘 내용을 저장해 변한 것만 갱신하며, 앱에서 캘린더로 한 방향임.
- Google 계정 캘린더를 대상으로 고르면 Google Calendar로 자동 동기화됨.
- 자정에는 `AlarmManager`로 위젯 데이터와 알람을 다시 만듦.

## Results

- 단위 테스트 **71건** 통과. 반복 규칙, 주간 루틴, 신호등, 백업 복원, 위젯 데이터, 투두 탭, 캘린더 동기화를 포함함.
- Android 15 에뮬레이터에서 위젯 추가, **앱을 열지 않은 체크**, 자정 갱신, 알림, 타이머 유지, 백업 공유, 태블릿 레이아웃을 확인함.
- 사진 인증, 수치 그래프, 템플릿, 주/월/연 계획, 주차 회고, 레벨/배지, 다크 모드, 백업 JSON 입출력을 구현함.

## Problems and Solutions

- 위젯과 앱의 동시 저장
  - 두 isolate가 같은 저장소에 써서 한쪽의 체크가 지워질 수 있었음.
  - 쓰기 직전에 디스크 최신값을 다시 읽고, 토글은 최신 상태를 뒤집도록 함.
- 변경 이후 과거 통계가 달라지는 문제
  - 모드를 바꾸거나 습관을 보관하면 지난 날의 달성률이 소급해서 바뀌었음.
  - 날짜별 모드 이력과 습관 종료일(`finishedOn`)을 저장해 **날짜 기준으로 계산**함.
- 디스크 쓰기 실패가 조용히 넘어감
  - `setString`이 `false`를 반환해도 메모리 상태만 바뀌어 화면과 저장 내용이 어긋났음.
  - `StorageWriteException`으로 올려 기록 롤백과 타이머 완료 취소가 동작하게 함.
- 백업 가져오기의 부분 적용
  - 형식이 틀린 백업이 기존 데이터를 일부만 덮어쓸 수 있었음.
  - 전체를 먼저 검증하고 저장소별로 되돌리며, 사진은 앱 전용 폴더 안의 파일만 읽고 지움.
- 자정 이후 위젯이 어제 데이터를 표시
  - 암시적 `DATE_CHANGED` 방송은 Android 8 이상의 매니페스트로 받을 수 없었음.
  - `AlarmManager`로 자정 직후 갱신을 예약하고, 데이터 날짜가 오늘이 아니면 새로 만들게 함.
- 위젯 요청 처리 오류
  - URI 호스트가 소문자로 정규화되어 `toggleTodo`가 인식되지 않았음.
  - 요청 이름을 소문자로 통일하고, 수신기는 `exported=false`로 외부 앱의 요청을 막음.
- 알림 예약 한도
  - 갤럭시는 예약 알람 수가 약 500개로 제한됨.
  - 앞으로 14일치, 최대 400개만 예약하고 데이터가 바뀔 때마다 한 번에 하나씩 다시 만듦.

## Limitations

- **Galaxy 실기기에서는 검증하지 못함.** 에뮬레이터 결과만 있음.
- 앱과 위젯이 정확히 같은 순간에 저장하는 경합은 재읽기로 창을 줄였을 뿐 완전히 막지 못함.
- 타이머는 앱 프로세스가 종료되면 사라지고, 앱을 14일 넘게 열지 않으면 알람이 끊김.
- 릴리스 APK는 debug 키로 서명되어 스토어 배포용이 아님.

## How to Run

```
flutter pub get
flutter test
flutter run
flutter build apk --release
```

- 빌드 결과는 `build/app/outputs/flutter-apk/app-release.apk`이며 Releases에도 올려 둠.
- 위젯은 설정 탭의 "홈 화면 위젯 추가"나 홈 화면 길게 누르기로 추가함.
- `SUnDo-web/`은 이전에 만든 PWA 프로토타입으로, 위젯을 만들 수 없어 Flutter로 옮김.

## References

- myroutine, https://myroutine.today/ko
