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
- **한계 해소 (3차 수정)**:
  - 타이머: 앱 단위 `HabitTimerManager`가 들고 있어 상세 시트를 닫아도 이어지고, 끝나면 자동 체크(테스트 2건)
  - 사진 백업: 사진을 base64로 `photoFiles`에 담아 내보내고 불러올 때 파일로 복원. 깨진 사진 데이터는 사전 검증에서 거부(테스트 1건)
  - 모드 이력: 날짜별 "이 날부터 이 모드"를 저장해 모드를 바꿔도 지난 날의 목록, 달성률, 신호등이 변하지 않음. 백업에 포함(테스트 2건)
  - 주 N회: 주가 끝난 일요일에 목표를 못 채웠으면 미달 1일로 셈. 중간 날은 여전히 실패로 세지 않음(테스트 1건)
- **codex 3차 검토 반영 (4차 수정)**:
  - 백업 사진 경로 안전성: 사진 읽기와 삭제는 앱 전용 사진 폴더 안의 파일만 허용, 백업에서 `photos/` 표시가 아닌 사진 경로는 연결을 끊음, 설정 최상위 타입이 틀린 백업은 거부
  - 모드 삭제: 습관의 모드 지정과 날짜별 이력을 그대로 두어 지난 날 통계 보존, 소속 모드가 모두 삭제된 습관은 지금부터 모든 모드에 나타남
  - 주 N회: 일요일에 완료했어도 주 목표 미달이면 체크하지 않은 마지막 날을 미달 1일로 계산
  - 개인 연속 일수와 주간 격자가 날짜별 모드 이력을 반영
  - 타이머: 습관이 삭제되면 타이머도 멈추고, 삭제된 습관의 기록은 만들지 않으며, 완료 기록 저장 실패 시 완료로 보이지 않게 되돌림
  - 테스트 50건
- **codex 4차 검토 반영 (5차 수정)**:
  - 보안: 위젯 백그라운드 수신기를 `exported=false`로 변경(외부 앱이 위젯 요청을 보낼 수 없음). 에뮬레이터에서 위젯 체크가 계속 동작함을 확인(75%에서 100%, 백그라운드 작업 SUCCESS)
  - 사진 복원은 기존 파일을 덮어쓰지 않고 항상 새 이름으로 저장(가져오기 도중 실패해도 기존 사진이 상하지 않음)
  - 모드 삭제 날짜를 이력(`modeDeleted`)으로 저장: 삭제한 날부터 소속 모드가 모두 사라진 습관이 모든 모드에 나타나고, 그 전 날짜는 당시 구성을 유지(다음 날 재계산해도 같음). 백업에 포함
  - 주 N회 미달 표시일은 쉬는 날과 다른 모드였던 날을 건너뜀
  - 기록 저장이 실패하면 메모리 기록도 되돌림, 체크 토글은 최신 기록을 읽은 뒤 뒤집음(위젯이 먼저 바꾼 상태를 거꾸로 되돌리지 않음), 삭제된 습관 확인을 최신 기록 읽기 직후로 이동
  - 통계 카드의 큰 화면 배치 폭을 본문 폭 기준으로 계산
  - 테스트 53건
- **codex 5차 검토 반영 (6차 수정)**:
  - 저장소가 디스크 쓰기 실패(false 반환)를 예외로 알림(`StorageWriteException`). 그래서 기록 롤백과 타이머 완료 취소가 실제로 작동
  - 백업 가져오기를 적용하다 실패하면 이전 데이터로 되돌리고, 복원하다 만 사진 파일도 지움(저장 실패를 흉내 낸 테스트 추가)
  - 주중에 종료한 주 N회 습관의 미달 표시일이 종료일 이후로 잡히지 않음
  - 백업의 반복 규칙 값(요일 0〜6, 날짜 1〜31, 횟수 1〜7, 간격 1〜365) 범위 검사
  - 테스트 56건
- **남은 한계**: 앱과 위젯이 정확히 같은 순간에 저장하는 경합과 알람 재예약 경합은 완전히 막지 못함(저장 직전 재읽기로 창을 줄임, 실제 재현은 못 함). 타이머는 앱 프로세스가 종료되면 사라짐. 갤럭시 실기기는 미검증

### 원본 대비 추가 구현
- 사진 인증, 수치 그래프, 템플릿, 계획(주/월/연), 주차 회고, 습관 복제/종료/보관, 기간 쉬기, 시간순 보기, 레벨과 배지
- 제외: 소셜(팔로우, 리액션, 비밀루틴), 결제, 계정 동기화, Apple Watch(iOS 전용)

---

## Change History

| Timestamp | Model | User Requirements | Task | Change Summary |
|-----------|-------|-------------------|------|----------------|
| 2026-10-16 22:40:00 KST | `claude-sonnet-5-5` | codex 최종 검토 | 검토 지적 반영 | 백업 원자성, 동시 저장, 보관, 알람, 위젯 자정 갱신, MVVM 정리, 테스트 34건 |
| 2026-10-16 21:40:00 KST | `claude-sonnet-5-5` | 웹이 아닌 갤럭시 앱, 위젯, 의존성 설치 | Flutter 앱 구현 | 웹 파일 SUnDo-web으로 이동, Flutter 앱과 네이티브 위젯 3종 구현, 환경 설치, 단위 테스트 29건 통과, 디버그/릴리스 APK 빌드 |
