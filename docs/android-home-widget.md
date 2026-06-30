# Android Home Widget

## 구현 범위

- Android 홈 화면 위젯은 4x2 기준이다.
- Flutter UI를 위젯에 직접 렌더링하지 않고, `home_widget`으로 저장한 데이터를 Android `AppWidgetProvider`가 RemoteViews에 바인딩한다.
- iOS WidgetKit은 이번 범위에서 제외한다.

## 표시 모드

### 기본 상태

- 레이아웃: `widget_fmk_default.xml`
- 조건: live snapshot이 없거나 expired일 때
- 표시: 국기, 그랑프리명, 최대 5개 주말 세션명, 날짜, KST 시작 시간

### 라이브 상태

- 레이아웃: `widget_fmk_live.xml`
- 조건: `LiveSessionSnapshot.isDisplayable`이 true일 때
- 표시: `LIVE` 또는 `RESULT` 배지, 국기/그랑프리명, 현재 랩/총 랩, 랩 진행률, Top 3 드라이버 코드
- `ended + visibleUntil` 미래 상태는 같은 라이브 레이아웃을 쓰고 배지만 `RESULT`로 표시한다.

## 저장 키

- 공통: `mode`, `gpFlag`, `gpName`
- 기본: `session1Name`~`session5Name`, `session1Date`~`session5Date`, `session1Time`~`session5Time`, `session1Visible`~`session5Visible`
- 라이브: `liveBadge`, `lapCurrent`, `lapTotal`, `p1Code`, `p2Code`, `p3Code`

## 폰트

- handoff의 `pretendard.xml`은 `pretendard_regular.ttf`, `pretendard_semibold.ttf`가 있을 때 쓰는 구조다.
- 현재 Android 위젯 리소스에는 해당 TTF 파일이 없으므로 RemoteViews XML에서는 `sans-serif` / `sans-serif-medium`을 사용한다.
- Flutter 앱 내부 텍스트는 `pubspec.yaml`에 등록된 Pretendard OTF를 계속 사용한다.

## 팀 컬러

- handoff의 `card_top_mclaren/ferrari/mercedes`는 실제 Top 3 팀으로 오해될 수 있어 사용하지 않는다.
- 위젯은 `card_top_p1/p2/p3` 중립 순위 강조 drawable을 사용한다.

## Android 수동 확인

1. `flutter build apk --debug`
2. Android 기기 또는 에뮬레이터에 앱 설치
3. 기존 위젯 제거
4. 앱을 한 번 실행해 위젯 데이터를 저장
5. 홈 화면에서 포매코 위젯 다시 추가
6. 기본 상태 UI 확인
7. mock live 상태에서 앱 실행 후 라이브 위젯 UI 확인
