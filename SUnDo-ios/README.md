# 루티닝 iOS

`SUnDo`(Android) 앱의 Dart 코드를 그대로 쓰는 iOS 버전. 화면, 저장소, 캘린더 동기화, 알림 로직이 같고, 플랫폼마다 다른 부분만 따로 둠.

## 현재 상태

- Dart 코드: `flutter analyze` 오류 없음, 단위 및 위젯 테스트 114건 통과(macOS에서 확인). iOS 앱 빌드는 Xcode가 있는 Mac이나 GitHub Actions에서 확인 필요
- iOS 빌드: GitHub Actions(macOS)에서 분석, 테스트, `flutter build ios --release --no-codesign`(위젯 확장 포함) 통과. 시뮬레이터 통합 테스트(`ios-simulator.yml`, iPhone 17 Pro iOS 26.2)로 앱 실행과 위젯 확장 포함까지 확인함. 위젯 동작과 실기기 실행은 아직 확인하지 못함
- 위젯: WidgetKit 소스와 `RoutiningWidget` 확장 타깃(Info.plist, App Group 권한, Runner에 포함)을 Xcode 프로젝트에 넣어 둠. 실제 빌드 확인은 CI 결과 참고

## Android와 달라지는 부분

- 알림은 예약 개수가 64개까지라서 상한을 60개로 둠(`AlarmPlanUseCase.maxAlarms`)
- 알림 권한은 설정 화면 버튼에서 요청함(시작할 때 묻지 않음)
- 위젯은 앱에서 추가할 수 없고, 홈 화면을 길게 눌러 추가함
- iOS 위젯은 누르면 앱이 열림. Android처럼 앱을 열지 않고 체크하는 동작은 아직 없음
- 위젯 스크롤: WidgetKit은 손가락 스크롤을 지원하지 않아서 iOS 17 이상에서는 위/아래 버튼으로 쪽을 넘겨 모든 항목을 봄(iOS 16 이하는 첫 쪽만 보임)
- 위젯 오른쪽 아래 "+" 버튼: `myroutine://add?kind=todo|routine` 주소로 앱을 열고 투두 추가 대화상자나 루틴 추가 화면을 띄움. 이를 위해 `Info.plist`에 `myroutine` URL 스킴을 등록했음
- 위젯 크기는 중간과 큰 것만 지원함(작은 크기는 "+" 버튼을 둘 수 없음)
- 위젯에 보이는 투두와 루틴 개수는 제한이 없고, 투두에는 시간이 함께 보임
- 캘린더, 카메라, 사진 접근 문구는 `ios/Runner/Info.plist`에 있음

## 빌드 순서 (Mac)

1. Xcode와 Flutter를 설치함
2. `flutter pub get`
3. `open ios/Runner.xcworkspace`로 Xcode를 열고 Runner 타깃의 Signing에서 Team을 고름(무료 Apple ID도 가능, 7일마다 재설치)
4. Signing & Capabilities에서 `App Groups`를 추가하고 `group.com.sundo.myRoutine`을 입력함
5. 시뮬레이터나 연결한 iPhone으로 `flutter run`

## 위젯 (Xcode)

- `RoutiningWidget` 타깃이 이미 프로젝트에 있고 Runner 앱에 포함됨(최소 iOS 17). 앱과 위젯 모두 `ios/Runner/Runner.entitlements`, `ios/RoutiningWidget/RoutiningWidget.entitlements`로 App Group `group.com.sundo.myRoutine`을 씀
- 실기기에 설치하려면 Xcode의 Signing에서 Runner와 RoutiningWidget 두 타깃 모두 Team을 고르고, App Group 권한이 두 타깃에 있는지 확인함
- 앱을 한 번 실행해 데이터를 저장한 뒤 홈 화면을 길게 눌러 위젯(루티닝 오늘의 루틴, 루티닝 투두)을 추가함

## Mac이 없을 때

- Windows에서는 iOS 시뮬레이터를 쓸 수 없고 빌드도 안 됨. Android 에뮬레이터와 별개임.
- 저장소 루트의 `.github/workflows/ios-build.yml`을 GitHub Actions에서 수동 실행하면 macOS 러너에서 분석, 테스트, 서명 없는 빌드까지 확인함. 실행 화면은 볼 수 없음.
- 실제 기기에 설치하려면 Mac과 Apple 계정이 필요하고, 배포(TestFlight, App Store)는 유료 Apple Developer Program(연 99달러)이 필요함.

## Android 코드와 맞추기

이 폴더의 `lib`와 `test`는 Android 쪽에서 복사한 것임. 달라진 파일은 `lib/data/services/notification_service.dart`, `lib/data/services/home_widget_service.dart`, `lib/domain/use_cases/alarm_plan_use_case.dart`, `lib/main.dart`, `lib/app/widget_background.dart`임. Android 쪽을 고친 뒤 이 폴더에 반영할 때는 이 파일들을 덮어쓰지 않게 주의함.
