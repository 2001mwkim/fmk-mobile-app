# Android Home Widget

## 구현 범위

- Android 홈 화면 위젯만 1차 구현한다.
- Flutter UI를 위젯에 직접 렌더링하지 않고, `home_widget`으로 저장한 텍스트 데이터를 Android `AppWidgetProvider`가 표시한다.
- iOS WidgetKit은 이번 범위에서 제외한다.

## 데이터 저장 키

- `fmk_widget_badge`
- `fmk_widget_title`
- `fmk_widget_primary`
- `fmk_widget_secondary`
- `fmk_widget_updated`

## 표시 우선순위

1. `LiveSessionSnapshot.isDisplayable`이면 라이브 또는 최종 결과를 표시한다.
2. 라이브 snapshot이 없거나 expired이면 기존 `races.dart`의 다음 그랑프리/다음 세션을 표시한다.
3. 모든 상태에서 `업데이트 HH:mm KST`를 표시한다.

## Android 수동 확인

1. `flutter build apk --debug`
2. Android 기기 또는 에뮬레이터에 앱 설치
3. 앱을 한 번 실행해 위젯 데이터를 저장
4. 홈 화면 길게 누르기
5. 위젯 목록에서 포매코 위젯 추가
6. 앱을 다시 열거나 라이브 데이터가 갱신될 때 위젯 표시가 갱신되는지 확인

## iOS WidgetKit 후속 과제

- Runner 앱과 Widget Extension의 App Group 설정
- Widget Extension target 추가
- SwiftUI WidgetKit view 구현
- `HomeWidget.setAppGroupId(...)` 적용
- 동일한 저장 키를 읽어 iOS 위젯에 매핑
