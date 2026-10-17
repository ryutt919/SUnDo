# Flutter 안드로이드 앱과 홈 화면 위젯 — 내 루틴

## Task Metadata
- **Created/updated at**: 2026-10-17 15:24:49 KST
- **Model used**: `claude-sonnet-5-5`
- **User requirements**: 웹페이지가 아니라 갤럭시 안드로이드 앱이 목표. 웹 파일은 SUnDo-web으로 옮기고, 그것을 바탕으로 Flutter 앱을 만든다(flutter-apply-architecture-best-practices 적용). 필요한 의존성 설치, 홈 화면 위젯, 구현하지 못한 것 재검토, 서브에이전트와 codex 활용, 마지막에 /codex:rescue로 요구사항과 구현 검토.
  - 2026-10-17 추가 요구: 위젯 스크롤과 "+" 버튼, 투두 날짜와 시간, "추가하기" 버튼, 투두와 루틴 일괄 삭제("관리"), 캘린더 일정의 투두 자동 추가, 통계의 투두와 계획 캘린더, 주간 계획 기간 표시. 같은 내용을 iOS(SUnDo-ios)에도 동일하게 반영하고 의존성과 SDK를 설치해 테스트 완료. 마지막에 Codex 검토.

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
- **codex 6차 검토 반영 (7차 수정)**: 백업 복구를 저장소별로 독립 실행하고 습관 복구가 실패하면 사진을 지우지 않음, 첫 실행 저장 실패와 위젯 저장 실패가 앱을 막지 않음, 습관이 잠깐 사라졌다 돌아와도 타이머 유지(없는 동안 시간 정지, 30초 넘게 없을 때만 정리). 테스트 58건
- **남은 한계**: 앱과 위젯이 정확히 같은 순간에 저장하는 경합과 알람 재예약 경합은 완전히 막지 못함(저장 직전 재읽기로 창을 줄임, 실제 재현은 못 함). 타이머는 앱 프로세스가 종료되면 사라짐. 갤럭시 실기기는 미검증

### 프리미엄 전체 개방과 투두 강화 (2026-10-17)
- **Current value/logic**: 사이트 프리미엄 표(습관, 일기, 메모, 반복, 형광펜, 통계, 투두 무제한, 광고 제거)를 코드와 대조해 모두 열려 있음을 확인. 남아 있던 모드 10개 상한도 제거
- **투두 탭**: 하단 탭에 "투두" 추가([todos_screen.dart](../lib/ui/features/todos/views/todos_screen.dart), [todos_view_model.dart](../lib/ui/features/todos/view_models/todos_view_model.dart)). 위 입력칸에 쓰고 엔터로 오늘 할 일 추가, 지난 미완료/오늘/예정/완료 구역, 스와이프 삭제, 지난 투두를 오늘로 옮기기, 완료 항목 지우기, 날짜 지정 추가
- **위젯 투두**: 오늘의 루틴 위젯에 오늘 투두와 지난 미완료 투두를 최대 3칸 표시하고, 체크는 `myroutine://toggletodo?id=`로 앱을 열지 않고 처리(URI 호스트는 소문자로 정규화되어 소문자로 씀). 에뮬레이터에서 확인
- **Rationale**: 사용자가 투두를 가장 중요한 기능으로 꼽았는데 기존에는 홈의 "+" 메뉴 뒤에만 있었음
- **테스트**: 62건 통과(투두 탭 3건, 위젯 투두 1건 추가, 모드 상한 테스트를 무제한 확인으로 교체)

### 루티닝 개편: 주간 루틴, 위젯, 캘린더 연동 (2026-10-17)
- **앱 이름**: 루티닝(런처 라벨, 위젯 이름, 앱 제목, 백업 문구). 패키지 ID `com.sundo.my_routine`은 데이터 보존을 위해 유지
- **주간 루틴**: 홈에 "매일 루틴 / 주간 루틴 / 회고" 탭. 주간 루틴은 `RepeatType.weekly`(주 N회, 루틴마다 N을 1〜7로 설정)이고 7일 칸을 눌러 체크. 매일 목록, 달성률, 신호등에서는 빠지고 주 단위 진행률(`WeeklyProgress`)로 봄. 구현 [routine_analyzer.dart](../lib/domain/use_cases/routine_analyzer.dart), [weekly_section.dart](../lib/ui/features/home/views/weekly_section.dart). 추가 메뉴에 "새 주간 루틴"
- **위젯**: 4종(오늘의 루틴, 투두, 주간 신호등, 월간 신호등). 체크 버튼 32dp에서 64dp로 2배, 행 높이 72dp, 위젯 높이에 들어가는 행만 그리고 나머지는 "외 n개 더 보기"(`RowWidgetProvider`가 크기 변경 시 다시 그림). 오늘의 루틴 위젯은 오늘 채울 주간 루틴을 매일 루틴 뒤에 붙임
- **캘린더 연동(B안)**: `device_calendar_plus` 0.10.2, 권한 `READ_CALENDAR`/`WRITE_CALENDAR`. [calendar_repository.dart](../lib/data/repositories/calendar_repository.dart)가 투두별 이벤트 ID와 서명을 저장하고 `sync`가 새로 만들기, 바뀐 것만 갱신, 사라진 투두의 이벤트 삭제를 함. 종일 일정, 완료한 투두는 제목 앞에 체크 표시. 앱에서 캘린더로 한 방향이며 위젯에서 바꾼 변화는 앱이 열릴 때 따라잡음. 설정에서 켜고 대상 캘린더를 고르며 "루티닝 일정 모두 지우기" 제공
- **양방향 동기화(추가)**: [calendar_repository.dart](../lib/data/repositories/calendar_repository.dart)가 제목과 날짜를 필드별로 (투두, 캘린더, 마지막 값) 세 갈래 비교. 같은 필드는 투두가 이기고 다른 필드는 각자 가져옴. 캘린더에서 지운 일정은 투두도 지움(설정 문구에 경고). 선택 기능으로 60일 안의 반복되지 않는 새 일정을 투두로 가져오고(가져온 일정은 지우거나 날짜를 옮기지 않음, 투두를 지우면 다시 가져오지 않음), 설정에 "지금 동기화" 제공. 에뮬레이터에서 캘린더 제목 변경 반영과 새 일정 가져오기 확인
- **용어 통일**: UI와 문서의 "습관"을 "루틴"으로 통일(코드 식별자 `Habit` 등은 유지)
- **계획 완료 체크**: `Goal.done` 추가. 계획 체크박스로 완료 처리(세부 항목도 모두 완료), 세부 항목을 모두 끝내면 자동 완료, 항목을 추가하면 다시 진행 중. 완료한 계획은 "완료한 계획" 구역에 초록 카드와 완료 칩으로 표시, 상단에 완료 n/m. 테스트 84건

- **검증**: 에뮬레이터에서 투두 일정 생성, 체크 해제 시 제목 갱신, 완료 지우기 시 삭제, 위젯 체크 후 앱 복귀 시 반영을 확인(로컬 테스트 캘린더 사용). 구글 계정 동기화와 갤럭시 실기기는 미검증
- **테스트**: 71건 통과(주간 루틴 3건, 캘린더 6건 추가)

### 투두 시간, 위젯 스크롤, 일괄 삭제, 통계 캘린더 (2026-10-17, 모델 `claude-sonnet-5-5`)
- **위젯 스크롤과 "+" 버튼**: 오늘의 루틴과 투두 위젯을 ListView 컬렉션으로 바꿔 위젯 안에서 위아래로 밀어 모든 항목을 봄(고정 8행, "외 n개 더 보기", 행 수 계산 삭제). 구현 [RowWidgetProvider.kt](../android/app/src/main/kotlin/com/sundo/my_routine/RowWidgetProvider.kt), [RowWidgetService.kt](../android/app/src/main/kotlin/com/sundo/my_routine/RowWidgetService.kt), [widget_row_item.xml](../android/app/src/main/res/layout/widget_row_item.xml). 체크는 PendingIntent 템플릿(MUTABLE 브로드캐스트)과 행별 fill-in intent(`myroutine://toggle`, `toggletodo`)로 앱을 열지 않고 처리. 오른쪽 아래 "+" 버튼은 `myroutine://add?kind=todo|routine` 딥링크로 앱을 열고 [widget_link.dart](../lib/app/widget_link.dart)가 해석해 [app_shell.dart](../lib/ui/features/shell/app_shell.dart)가 투두 추가 대화상자 또는 새 루틴 화면을 염. [MainActivity.kt](../android/app/src/main/kotlin/com/sundo/my_routine/MainActivity.kt)는 새 인텐트를 `setIntent`로 보관해 앱이 준비되기 전에 도착한 링크도 읽음. 스냅샷 JSON에서 `more`, `todoMore`를 없애고 루틴과 투두를 개수 제한 없이 담음
- **투두 시간**: `Todo.time`('HH:mm', 빈 문자열이면 종일, 예전 데이터와 호환). 추가와 수정 대화상자에서 날짜를 고르고 "시간 추가"를 누르면 시간을 고름(지우면 종일). 같은 날은 시간 있는 것을 시간 순으로 먼저 정렬(`sortTodos`). 위젯 행에는 "오늘 14:30"처럼 표시. 시간을 넣은 투두에 알림은 만들지 않음(사용자 기본값)
- **투두 추가 방식**: 위쪽 입력칸과 엔터 추가를 없애고 오른쪽 아래 "추가하기" 버튼으로 대체([todos_screen.dart](../lib/ui/features/todos/views/todos_screen.dart)). 날짜는 기존처럼 항상 보이는 날짜 버튼(사용자가 "그대로"라고 확인)
- **일괄 삭제("관리")**: 투두 탭, 홈의 매일 루틴 탭, 주간 루틴 탭에 "관리" 버튼. 공용 화면 [bulk_delete_screen.dart](../lib/ui/features/manage/views/bulk_delete_screen.dart)에서 여러 개를 고르고 전체 선택, 확인 대화상자 후 삭제. 저장소에 `deleteTodos`, `deleteHabits`(저장 한 번, 위젯이 방금 한 체크를 지우지 않도록 최신 기록에서 시작) 추가
- **캘린더 일정 자동 투두**: 원인은 "새 일정 가져오기"가 기본 꺼짐이어서 설정에서 직접 켜야 했던 것. 기본값을 켬으로 바꾸고, 예전에 꺼진 채 저장된 설정은 스키마 2로 올라올 때 한 번만 켬(그 뒤 직접 끈 것은 유지). 시각이 있는 일정은 시간까지 투두로 가져오고 캘린더에서 시간을 바꾸면 따라감. 앱이 켜져 있으면 10분마다 확인([app_sync.dart](../lib/app/app_sync.dart)). 반복 일정은 여전히 가져오지 않음. 캘린더로 나가는 일정은 종일 그대로(투두 시간은 캘린더에 보내지 않음)
- **통계 캘린더**: [stats_screen.dart](../lib/ui/features/stats/views/stats_screen.dart)에 투두 캘린더(날마다 완료/전체 개수, 모두 완료/일부/못 한 날/예정 색, 칸을 누르면 그날 투두를 보고 체크)와 계획 캘린더(칸 색은 그 주 주간 계획 평균 진행률, 월간과 연간 계획 진행률 막대, 칸을 누르면 그날을 덮는 주간, 월간, 연간 계획)를 추가. 모든 캘린더가 같은 달 이동 버튼을 씀
- **주간 계획 기간 표시**: "10월 12일 - 10월 18일"(월요일부터 일요일, 해가 바뀌는 주는 연도 포함), 좌우 삼각형 화살표
- **iOS 동일 반영**: Dart 코드와 테스트는 같은 파일을 SUnDo-ios에 복사(플랫폼별로 다른 5개 파일은 그대로). WidgetKit 위젯([RoutiningWidget.swift](../SUnDo-ios/ios/RoutiningWidget/RoutiningWidget.swift))은 손가락 스크롤이 불가능해 iOS 17 이상에서 위/아래 버튼으로 쪽을 넘기고, "+"는 Link로 같은 딥링크를 염. `Info.plist`에 `myroutine` URL 스킴 등록. 작은 크기 위젯은 Link를 둘 수 없어 제외
- **검증**: 단위와 위젯 테스트 114건(Android, iOS 각각) 통과, `flutter analyze` 오류와 경고 없음(기존 info 제외). Android 에뮬레이터(Pixel 8, API 35)에서 투두 추가 대화상자, 일괄 삭제 화면, 통계 캘린더, 위젯 표시와 스크롤(23개 항목), 위젯 체크(앱을 열지 않고 완료), 위젯 "+"(앱이 꺼진 상태와 켜진 상태 모두) 확인. Swift는 macOS SDK로 `swiftc -typecheck` 통과
- **Codex 검토 반영 (2026-10-17)**: 지적 5건 모두 수정. (1) 투두를 바꾸기 직전에 디스크 최신 목록을 읽어(`_refreshTodos`) 위젯이 방금 한 체크를 덮어쓰거나 지운 투두를 되살리지 않음, (2) 루틴 일괄 삭제는 루틴 저장 뒤에 최신 기록을 읽어 바로 고쳐 저장, (3) iOS 위젯 링크에 `homeWidget` 쿼리를 붙여 `home_widget` 플러그인이 `+` 링크를 앱에 전달, (4) 캘린더 시간 가져오기가 최신 투두에 적용돼 앱의 완료 처리를 되돌리지 않음, (5) iOS 위젯 쪽 번호를 목록 길이에 맞게 보정해 저장. 회귀 테스트 3건 추가. Android PendingIntent 템플릿 구조와 플래그, 스냅샷 호환은 문제 없음으로 확인
- **iOS 빌드 검증 (2026-10-17 15:41:02 KST)**: 이 Mac에는 Xcode가 없어(설치에 Apple ID 로그인 필요) `xcodeproj` gem으로 `RoutiningWidget` 확장 타깃(앱 확장, 최소 iOS 17, Info.plist, App Group 권한, Runner에 포함)을 프로젝트에 추가. 사용자 승인 후 main을 push하고 GitHub Actions `ios-build.yml`을 실행해 macOS에서 분석, 테스트 114건, `flutter build ios --release --no-codesign` 통과 확인(워크플로의 `flutter analyze`는 기존 info 경고 때문에 실패해 `--no-fatal-infos`로 바꿈)
- **iOS 시뮬레이터 통합 테스트 (2026-10-17 16:02:34 KST)**: [ios-simulator.yml](../.github/workflows/ios-simulator.yml)(수동 실행)이 macOS 러너의 iPhone 17 Pro 시뮬레이터(iOS 26.2)에 앱을 설치해 [app_test.dart](../SUnDo-ios/integration_test/app_test.dart)를 실행(투두 추가와 시간 선택, 관리에서 일괄 삭제, 통계 투두/계획 캘린더)하고 `Runner.app/PlugIns/RoutiningWidget.appex` 포함을 확인. 이 과정에서 실제 결함 3건을 찾아 고침: (1) 위젯 확장이 Flutter xcconfig 없이 버전 값이 풀리지 않아 설치 실패 → 확장 타깃에 Runner와 같은 xcconfig 지정, (2) iPhone 폭에서 홈 상단 줄 9.4px 넘침 → 날짜 영역을 Flexible로 축소 가능하게, (3) 탭마다 있는 FAB의 Hero 태그 충돌(Android에도 해당) → FAB마다 고유 `heroTag`
- **iOS 위젯 Swift 로직 실행 확인 (2026-10-17 16:10:53 KST)**: [main.swift](../SUnDo-ios/ios/RoutiningWidgetTests/main.swift)가 위젯 파일(@main 제외)과 함께 macOS에서 컴파일되어 실행됨(Mac과 CI 모두 14개 확인 통과). Dart가 만든 실제 snapshot JSON([snapshot_fixture.json](../SUnDo-ios/ios/RoutiningWidgetTests/snapshot_fixture.json))을 위젯이 그대로 읽는지, 크기별 행 수, 목록이 줄어들 때 쪽 보정과 저장, 쪽 넘김 버튼(App Intent)의 증감과 하한을 검증
- **미검증**: iOS 위젯의 화면 렌더링과 실제 탭 동작(홈 화면에 올려 눌러 보기), "+" 딥링크가 앱에서 열리는 경로, iOS 실기기 실행, 갤럭시 실기기
- **한계**: 위젯 행 본문 탭은 동작 없음(컬렉션은 템플릿 하나만 가질 수 있어 체크 버튼만 연결). "+" 버튼이 목록 위에 겹쳐 스크롤 중 오른쪽 아래 행의 체크 버튼을 가릴 수 있음(끝까지 내리면 여백 있음)

### 원본 대비 추가 구현
- 사진 인증, 수치 그래프, 템플릿, 계획(주/월/연), 주차 회고, 습관 복제/종료/보관, 기간 쉬기, 시간순 보기, 레벨과 배지
- 제외: 소셜(팔로우, 리액션, 비밀루틴), 결제, 계정 동기화, Apple Watch(iOS 전용)

---

## Change History

| Timestamp | Model | User Requirements | Task | Change Summary |
|-----------|-------|-------------------|------|----------------|
| 2026-10-17 15:24:49 KST | `claude-sonnet-5-5` | 위젯 스크롤과 +, 투두 날짜와 시간, 추가하기 버튼, 일괄 삭제, 캘린더 자동 투두, 통계 캘린더, 주간 계획 기간, iOS 동일 반영 | 투두와 위젯 개편 | 위젯 8행 고정 → 스크롤 목록, 투두 시간 추가, 입력칸 → 추가하기 버튼, 관리 화면, 캘린더 가져오기 기본 꺼짐 → 켜짐, 통계 캘린더 2종, 테스트 84 → 114건, Codex 검토 5건 반영, iOS 동일 반영 |
| 2026-10-17 17:40:00 KST | `claude-sonnet-5-5` | 앱 이름 루티닝, 위젯 투두, 체크 버튼 2배, 주간 루틴, 캘린더 연동 | 루티닝 개편 | 이름 변경, 주간 루틴 탭, 투두 위젯, 큰 체크 버튼, 기기 캘린더 한 방향 동기화, 테스트 62 → 71건 |
| 2026-10-17 15:40:00 KST | `claude-sonnet-5-5` | 프리미엄 전부 사용, 제한 없애기, 투두가 가장 중요 | 모드 상한 제거, 투두 탭, 위젯 투두 | 모드 10개 상한 → 무제한, 투두 전용 탭 신설, 위젯에 투두 3칸과 체크 추가, 테스트 58 → 62건 |
| 2026-10-16 22:40:00 KST | `claude-sonnet-5-5` | codex 최종 검토 | 검토 지적 반영 | 백업 원자성, 동시 저장, 보관, 알람, 위젯 자정 갱신, MVVM 정리, 테스트 34건 |
| 2026-10-16 21:40:00 KST | `claude-sonnet-5-5` | 웹이 아닌 갤럭시 앱, 위젯, 의존성 설치 | Flutter 앱 구현 | 웹 파일 SUnDo-web으로 이동, Flutter 앱과 네이티브 위젯 3종 구현, 환경 설치, 단위 테스트 29건 통과, 디버그/릴리스 APK 빌드 |
