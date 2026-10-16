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

### codex 검토 반영 (2026-10-16)
- **백업 불러오기**: 습관과 회고 데이터를 모두 해석해 본 뒤에만 덮어씀. 형식이 틀리면 기존 데이터 유지(테스트 추가)
- **앱과 위젯 동시 저장**: 기록 쓰기 직전에 디스크 최신값을 다시 읽음(테스트 추가)
- **보관**: 어제까지만 나타나게 해서 과거 달성률과 신호등이 바뀌지 않음. 복원 시 종료일 해제
- **알람**: 재예약을 한 번에 하나씩 실행, 최대 400개 상한(갤럭시 500개 한도 대비), 위젯 콜백에서도 재예약(위젯으로 체크한 습관의 알람 취소, 앱을 안 열어도 예약 연장)
- **위젯 날짜 갱신**: 정적 방송 대신 AlarmManager로 자정 직후 갱신을 예약, 데이터가 어제 것이면 새로 만들게 함, 시간대 변경 시 알람도 재계산
- **MVVM 우회 제거**: 모드 시트와 투두 편집이 ModesViewModel, TodoEditorViewModel을 통해 저장소를 사용
- **codex 재검토 후 추가 수정**: 백업의 설정 부분까지 사전 검증, 습관/모드 삭제 전에 최신 기록 재읽기, 이미 종료한 습관을 보관해도 종료일 유지, 보관 습관이 과거 기간의 습관별 통계와 주간 보기에 남음. 테스트 38건 통과
- **알려진 한계(미수정)**: 앱과 위젯이 정확히 같은 순간에 저장하는 경합과 알람 재예약 경합은 완전히 막지 못함(저장 직전 재읽기로 창을 줄임, 실제 재현은 못 함), 타이머는 상세 시트를 닫으면 종료, 사진은 JSON 백업에 포함되지 않음, 주 N회 습관의 지난 미달은 통계에 반영되지 않음(정책), 모드는 과거 날짜에도 현재 선택이 적용됨

### 원본 대비 추가 구현
- 사진 인증, 수치 그래프, 템플릿, 계획(주/월/연), 주차 회고, 습관 복제/종료/보관, 기간 쉬기, 시간순 보기, 레벨과 배지
- 제외: 소셜(팔로우, 리액션, 비밀루틴), 결제, 계정 동기화, Apple Watch(iOS 전용)

---

## Change History

| Timestamp | Model | User Requirements | Task | Change Summary |
|-----------|-------|-------------------|------|----------------|
| 2026-10-16 22:40:00 KST | `claude-sonnet-5-5` | codex 최종 검토 | 검토 지적 반영 | 백업 원자성, 동시 저장, 보관, 알람, 위젯 자정 갱신, MVVM 정리, 테스트 34건 |
| 2026-10-16 21:40:00 KST | `claude-sonnet-5-5` | 웹이 아닌 갤럭시 앱, 위젯, 의존성 설치 | Flutter 앱 구현 | 웹 파일 SUnDo-web으로 이동, Flutter 앱과 네이티브 위젯 3종 구현, 환경 설치, 단위 테스트 29건 통과, 디버그/릴리스 APK 빌드 |
