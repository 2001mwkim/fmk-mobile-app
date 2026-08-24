# Android Home Widget

## 구현 범위

- Android 홈 화면 위젯은 4x2 기준이다.
- Flutter UI를 위젯에 직접 렌더링하지 않고, `home_widget`으로 저장한 데이터를 Android `AppWidgetProvider`가 RemoteViews에 바인딩한다.
- **위젯 Provider 는 네트워크를 쓰지 않는다.** 앱(또는 WorkManager)이 미리 저장해 둔 값을 그릴 뿐이다. 이 제약이 아래 "라이브 제거" 의 이유다.

## 표시 모드

일정 한 가지뿐이다(2026-08 기준).

- 레이아웃: `widget_fmk_default.xml`(4x2) / `widget_fmk_compact.xml`(2셀, <180dp)
- 표시: 국기, 그랑프리명, 최대 5개 주말 세션명, 날짜, KST 시작 시간
- 콤팩트는 다음 세션(하이라이트) 한 건만 크게 보여준다

### 라이브·결과 화면은 왜 없어졌나

2026-08 이전에는 우측 화면에 라이브 순위(mode `live`) 또는 최근 확정 결과 Top3
(mode `result`)를 그리고 토글로 오갔다. 이를 유지하려면 위젯이 직접 받아올 수 없으니
앱이 WorkManager 로 30분마다 대신 폴링해야 했고, 그 요청이 Vercel 무료 한도(엣지 요청
월 100만)를 압박했다. 그래서 라이브·결과 화면과 전용 레이아웃·Provider 를 전부 제거했다.
자세한 배경은 `CLAUDE.md` 의 "외부 비용 제약" 참고.

iOS 는 사정이 다르다. WidgetKit 은 OS 가 갱신 예산(하루 수십 회)을 배급하고 위젯이
스스로 fetch 하므로 비용이 자동으로 상한선에 묶인다. 그래서 iOS 쪽 코드는 지우지 않고
등록만 해제해 뒀다(`ios/FmkWidgets/FmkSplitWidgets.swift`).

## 저장 키

- 일정: `scheduleGpFlag`, `scheduleGpName`, `scheduleRaceId`, `sessionHighlightIndex`,
  `session1Name`~`session5Name`, `session1Date`~`session5Date`,
  `session1Time`~`session5Time`, `session1Visible`~`session5Visible`,
  `session1Id`~`session5Id`, `session1StartEpoch`/`EndEpoch`(iOS 타임라인용)
- 테마: `widgetThemeMode`(다크/라이트/시스템)
- 애플워치 최근 결과 전용: `lrGpName`, `lrGpFlag`, `lrLabel`, `lr1~3Name/Time/Pos/Color`
  (iOS 에서만 저장 — `FmkHomeWidgetBridge._saveLatestResultExtras`)

`mode`, `liveBadge`, `lapCurrent`, `lapTotal`, `p1~p3*` 는 라이브 시절의 잔재로 아직
저장되지만 항상 기본값이고 읽는 쪽이 없다. 지우려면 Dart 브리지와 iOS `FmkPayloadStore`
를 함께 고쳐야 한다.

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
5. 홈 화면에서 비아 포뮬러 위젯 다시 추가
6. 일정 화면 UI 확인(4x2 / 2셀 콤팩트 양쪽)
