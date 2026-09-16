# iOS 일정 위젯 자동 전환

## 동작

- 앱 실행 시 네트워크 응답을 기다리기 전에 시즌 전체 일정을 App Group의 `scheduleCalendarV1`에 한 번에 저장한다. 기존 단일 GP 키는 유지한다.
- 활성 일정 위젯 `FmkHomeWidget`은 각 타임라인 시점에 해당 GP를 선택한다. 레이스 예상 종료 시각에 다음 GP로 넘어간다.
- 한국 시간 자정, 세션 시작/종료, GP 종료를 포함한 35일치 엔트리를 미리 제공한다. 위젯은 하루 뒤 타임라인 재생성을 요청하며, 재생성은 저장된 시즌 데이터만 사용한다.
- 마지막 레이스 진행 중에는 레이스를 표시하고, 이후에는 지난 FP1 대신 다음 일정이 없음을 표시한다.
- 새 데이터가 없거나 형식이 잘못됐으면 기존 단일 GP 데이터를 사용한다. 업데이트 후 새 일정 저장을 위해 앱을 한 번 실행해야 한다.
- 앱에 들어 있는 일정 기준이며, 일정 변경이나 다음 시즌 추가는 갱신된 앱 데이터 저장이 필요하다. 실시간 경기 지연은 추적하지 않는다.
- 순위/MY PICKS의 서버 데이터 갱신과 Live Activity는 이번 변경 대상이 아니다. 공유 payload를 쓰는 Apple Watch는 기존 동작을 유지한다.

## 자동 검증

```sh
flutter test test/fmk_home_widget_bridge_test.dart test/ios_widget_calendar_publish_test.dart test/widget_theme_controller_test.dart test/notification_settings_controller_test.dart
flutter analyze lib/services/fmk_home_widget_bridge.dart test/fmk_home_widget_bridge_test.dart test/ios_widget_calendar_publish_test.dart
```

macOS에서 저장/선택/타임라인의 실제 Swift 코드를 컴파일해 경계 테스트를 실행한다. 아래 명령은 저장소 루트 기준이며 Xcode 명령줄 도구가 필요하다.

```sh
widget_test_dir=$(mktemp -d)
xcrun swiftc -target "$(uname -m)-apple-macosx12.0" \
  ios/FmkWidgets/FmkPayloadStore.swift \
  ios/FmkWidgets/FmkLive.swift \
  test/native/widget_schedule_test.swift \
  -o "$widget_test_dir/widget-schedule-test"
"$widget_test_dir/widget-schedule-test"
```

Swift 테스트: GP 종료 직전/정각, 마지막 레이스 진행 중, 시즌 종료, KST 자정과 D-day, 정렬/중복 제거, 지연된 갱신, 잘못된 JSON/알 수 없는 버전, 이전 데이터 호환성.

## iPhone 배포 전 검증

1. Xcode에서 Runner와 FmkWidgets 및 공유 소스를 쓰는 Watch 타깃을 빌드한다.
2. 앱을 한 번 실행하고 잠금화면의 원형·직사각형·한 줄 위젯, 홈 화면의 소형·중형 위젯을 추가한다.
3. 테스트 빌드의 일정 fixture에 가까운 미래의 자정/세션/GP 종료 경계를 설정한다. 앱을 닫고 경계를 지나도 올바른 행·GP가 표시되는지 확인한다. 기기 시계 변경은 WidgetKit 자체 재로딩을 유발할 수 있으므로 그것만으로 검증하지 않는다.
4. 네트워크를 끈 상태와 기기 시간대를 바꾼 상태에서도 같은 KST 일정으로 전환되는지 확인한다.
5. 시즌 마지막 종료 이후 지난 FP1 또는 잘못된 D-DAY가 표시되지 않는지 확인한다.
6. 구버전에서 업데이트 후 첫 실행 전/후, 위젯 재추가, Watch 표시, 기존 순위 위젯을 확인한다.

WidgetKit은 실제 표시/재로딩 시각을 최종 결정한다. 일정 엔트리를 미리 제공해 앱 의존성을 제거하지만 OS 수준의 지연까지 보장하지는 않는다.

현재 Windows 작업 환경에서는 위 Dart 테스트만 실행 가능하며, Swift 실행·Xcode 빌드·실기기 검증은 별도로 필요하다.
