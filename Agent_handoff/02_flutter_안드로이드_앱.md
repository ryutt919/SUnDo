# Flutter 안드로이드 앱과 홈 화면 위젯 — 내 루틴

## Task Metadata
- **Created/updated at**: 2026-10-16 21:40:00 KST
- **Model used**: `claude-sonnet-5-5`
- **User requirements**: 웹페이지가 아니라 갤럭시 안드로이드 앱이 목표. 웹 파일은 SUnDo-web으로 옮기고, 그것을 바탕으로 Flutter 앱을 만든다(flutter-apply-architecture-best-practices 적용). 필요한 의존성 설치, 홈 화면 위젯, 구현하지 못한 것 재검토, 서브에이전트와 codex 활용, 마지막에 /codex:rescue로 요구사항과 구현 검토.

## Component Status

### 개발 환경
- **Current value/logic**: Flutter 3.47.7(Dart 3.13.5), JDK 17(Microsoft OpenJDK 17.0.20.1), Android SDK(platform-tools, platforms android-35/36, build-tools 35.0.0/36.0.0), NDK r28c, CMake 3.22.1
- **Implementation**: `C:\dev\flutter`, `C:\dev\android-sdk`, 사용자 환경변수 ANDROID_HOME, JAVA_HOME, PATH 추가. Android SDK 라이선스 8개 수락(사용자 허가에 따름)
- **Rationale**: 사용자가 필요한 의존성 설치를 허가함

### 아키텍처
- **Current value/logic**: UI(MVVM, ChangeNotifier) / Domain(불변 모델, 유스케이스) / Data(서비스, 저장소). 의존성은 provider
- **Implementation**: `lib/app`(조립), `lib/data/{services,repositories}`, `lib/domain/{models,use_cases}`, `lib/ui/{core,features/<기능>/{view_models,views}}`
- **Rationale**: 스킬의 권장 구조. 도메인 모델은 freezed 코드 생성 없이 직접 작성한 불변 클래스와 copyWith(빌드 단계를 줄이기 위해)

### 데이터 저장
- **Current value/logic**: shared_preferences에 JSON 문자열(habits, modes, activeMode, logs, rest, todos, memos, goals, reviews, settings)
- **Implementation**: [storage_service.dart](../lib/data/services/storage_service.dart), 저장소 3개(routine, journal, settings)
- **Rationale**: 웹앱 백업 JSON과 같은 필드 이름을 써서 웹에서 쓰던 데이터를 그대로 불러올 수 있음. 깨진 JSON은 `.corrupt.<시각>` 키에 보관

### 신호등과 반복 규칙
- **Current value/logic**: 60% 이상 초록, 20% 이상 노랑, 미만 빨강, 쉬는 날 파랑, 오늘 0%와 미래는 색 없음. 반복: 매일, 요일, 주 N회, N일마다, 매월 날짜
- **Implementation**: [routine_analyzer.dart](../lib/domain/use_cases/routine_analyzer.dart), 테스트 [routine_analyzer_test.dart](../test/domain/routine_analyzer_test.dart)

### 홈 화면 위젯 (네이티브 Kotlin)
- **Current value/logic**: 위젯 3종. 오늘의 루틴(최대 8행, 이모지 칸 탭으로 앱을 열지 않고 체크), 주간 신호등, 월간 신호등
- **Implementation**: Flutter가 `snapshot` JSON을 home_widget으로 저장하고 위젯 갱신 요청. Kotlin은 [TodayWidgetProvider.kt](../android/app/src/main/kotlin/com/sundo/my_routine/TodayWidgetProvider.kt), WeekWidgetProvider.kt, MonthWidgetProvider.kt가 JSON을 읽어 RemoteViews로 그림. 체크는 `myroutine://toggle?id=` 백그라운드 콜백([widget_background.dart](../lib/app/widget_background.dart))이 저장소를 바꾸고 위젯을 다시 그림. 자정에 DATE_CHANGED 방송을 받아 `myroutine://refresh`로 새 날 데이터를 만듦
- **Rationale**: PWA로는 위젯을 만들 수 없어 Flutter와 네이티브 위젯으로 전환. 위젯은 라이트 테마 고정(다크 모드 대응 미구현)

### 알람
- **Current value/logic**: 습관별 알람과 아침/저녁 전체 알람을 앞으로 14일치, 해야 하는 날과 쉬는 날을 반영해 예약. 데이터가 바뀔 때마다 다시 예약
- **Implementation**: [alarm_plan_use_case.dart](../lib/domain/use_cases/alarm_plan_use_case.dart), [notification_service.dart](../lib/data/services/notification_service.dart). 정확 알람 권한이 없으면 부정확 모드로 예약
- **Rationale**: 앱을 14일 넘게 안 열면 알람이 끊김(한계)

### 원본 대비 추가 구현
- 사진 인증, 수치 그래프, 템플릿, 계획(주/월/연), 주차 회고, 습관 복제/종료/보관, 기간 쉬기, 시간순 보기, 레벨과 배지
- 제외: 소셜(팔로우, 리액션, 비밀루틴), 결제, 계정 동기화, Apple Watch(iOS 전용)

---

## Change History

| Timestamp | Model | User Requirements | Task | Change Summary |
|-----------|-------|-------------------|------|----------------|
| 2026-10-16 21:40:00 KST | `claude-sonnet-5-5` | 웹이 아닌 갤럭시 앱, 위젯, 의존성 설치 | Flutter 앱 구현 | 웹 파일 SUnDo-web으로 이동, Flutter 앱과 네이티브 위젯 3종 구현, 환경 설치, 단위 테스트 29건 통과, 디버그/릴리스 APK 빌드 |
