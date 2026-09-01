# 비아 포뮬러 / Via Formula (fmk_app)

포뮬러 매거진 코리아(Formula Magazine Korea)가 운영하는 F1 팬용 Flutter 앱(Android 우선). 2026 시즌 일정·순위·직관 가이드·라이브 타이밍을 제공한다. 기존 Next.js 웹앱의 UI를 이식한 프로젝트라서, 화면 코드 주석에 웹 컴포넌트 출처(`components/...tsx`)와 색상 원본값을 적는 관례가 있다.

- **앱 표시명**: "비아 포뮬러" (영문 브랜드 "Via Formula", 스토어명 후보 "비아 포뮬러 - 일정·라이브·직관")
- **운영 브랜드**: "Formula Magazine Korea" / "포뮬러 매거진 코리아" — 출처·운영사 맥락에서는 이 이름을 유지한다
- 패키지/번들 ID(`kr.formulamagazine.fmk`)와 `fmk_*` 코드 식별자·파일명은 브랜드 변경과 무관하게 **변경 금지**

## 자매 저장소 (중요)

라이브 데이터는 별도 저장소의 collector가 제공한다:

- **웹/collector**: GitHub `2001mwkim/fmk-f1-calendar` — Windows 머신은 `C:\Users\2001m\fmk-f1-calendar`, Mac 은 `~/Documents/fmk-f1-calendar`
- collector 소스: `scripts/signalr-live-collector.ts` — F1 SignalR 피드 구독 → `live.json` HTTP 서빙
- **배포**: main 브랜치 push → Railway 자동 배포 (`https://live-production-c03d.up.railway.app/live.json`)
- 타입 동기화: 웹 `lib/live/types.ts` ↔ 앱 `lib/models/live_session.dart`는 **수동 복제** 관계다. collector가 내려주는 필드를 바꾸면 양쪽 모두 고칠 것.
- collector mock 모드: `LIVE_MOCK_MODE=live LIVE_MOCK_SESSION_TYPE=race|sprint|qualifying|practice npm run live-collector:dev` (+`LIVE_MOCK_NO_LAP_TIMES=1`로 랩타임 수신 전 상태 재현)
- 소식(뉴스) 수집기도 같은 저장소: `scripts/news-rss-collector.ts` (`npm run news-collector`) — 계약은 앱 `docs/news_api_contract.md`, 사용법은 `docs/news_rss_collector.md`. Railway collector 프로세스가 주기 수집(`scripts/news-scheduler.ts`, 기본 30분) 후 `/news.json` 으로 서빙하고, Vercel `/api/news` 가 `NEWS_JSON_REMOTE_URL` 로 이를 중계한다(배포 계획: `docs/news_deployment_plan.md`). 앱 기본값은 `HttpNewsRepository`(origin 은 `lib/services/news_repository.dart` 의 `kNewsApiBaseUrl`, `--dart-define=NEWS_API_BASE_URL` 로 재정의)
- 챔피언십 순위도 같은 방식: `scripts/standings-scheduler.ts` 가 F1DB 릴리스를 주기 확인(기본 6시간, 태그 같으면 다운로드 스킵) → `/standings.json` → Vercel `/api/standings`(`STANDINGS_JSON_REMOTE_URL`). 앱은 `HttpStandingsRepository` 로 받아오되 **실패 시 `lib/data/standings.dart` 정적 데이터로 폴백** — 정적 파일은 삭제 금지(오프라인/서버 장애 대비 초기값). 수동 갱신 스크립트 `update-standings.ts` 도 같은 `standings-fetcher.ts` 를 사용
- 레이스 결과도 같은 방식: `scripts/race-results-scheduler.ts` → `/race-results.json` → Vercel `/api/race-results`(`RACE_RESULTS_JSON_REMOTE_URL`). **앱은 round 가 아니라 raceId 로 조회**(취소 GP 로 F1DB round 와 앱 round 가 어긋남 — 서버가 circuitId 조인으로 앱 raceId 를 내려줌). GP 상세 화면이 `HttpRaceResultsRepository` 로 **세션별 결과**(`sessions[]`: FP1~레이스, 세션 선택 탭)를 받고, 실패/미존재 시 정적 레이스 결과 또는 "결과 데이터 준비 중" 카드 유지. 표시 규칙: 레이스/스프린트는 1위 총시간+갭, 연습/퀄리는 행별 랩타임. `circuitIdByRaceId` 맵은 `race-results-fetcher.ts` 가 단일 출처

## 명령어

```bash
# 개발 머신은 두 대다: Windows(안드로이드 릴리스 서명 키 보유)와 Mac(iOS/워치 빌드).
# Windows 에서 flutter 가 PATH 에 없으면: C:\Users\2001m\flutter\bin\flutter.bat
# Mac 은 /opt/homebrew/bin/flutter (PATH 에 있음)
flutter analyze
flutter test
# 실기기용 빌드는 프로덕션 collector URL을 주입한다
flutter build apk --debug --dart-define=LIVE_JSON_URL=https://live-production-c03d.up.railway.app/live.json
# 릴리스 빌드 — 라이브 URL(Cloudflare)도 레이스 중 10초 폴링도 기본값이라 플래그 불필요
flutter build appbundle --release
# 로컬 collector 사용 시(dart-define 생략): 기본값 http://localhost:8787/live.json
```

## 구조

- `lib/data/` — 정적 데이터(2026 일정 `races.dart`, 결과 `race_results.dart`, 순위, 서킷, 국기, 팀 컬러) + **드라이버 매핑 `drivers.dart`**(코드→한글 이름/팀 액센트 — 시즌 라인업 변경 시 이 파일만 수정)
- `lib/models/live_session.dart` — 라이브 스냅샷 모델 + 표시 규칙(노출 기한, 세션 활성 판정 등 정책 함수 다수)
- `lib/services/` — `live_session_service`(live.json fetch/파싱), `live_session_controller`(폴링·유지 정책), `notification_*`(로컬 알림), `fmk_home_widget_bridge`(Android 홈 위젯 데이터 저장)
- `lib/screens/`, `lib/widgets/` — 화면/위젯. 순위 패널 공용 UI는 `widgets/classification_panel_parts.dart`, 트랙맵 SVG 렌더러는 `widgets/circuit_map.dart`
- `android/.../FmkHomeWidgetProvider.kt` — **일정 위젯**(일정만 그린다). 라이브/결과 화면과 토글은 2026-08 에 제거했다 — 위젯 Provider 는 네트워크를 쓰지 못해서 라이브를 보여주려면 앱이 주기 폴링을 대신 돌려야 하는데, 그 폴링이 Vercel 무료 한도를 잡아먹었다(아래 '외부 비용 제약'). 위젯 데이터 키는 브리지와 Kotlin 양쪽에 문자열로 존재하므로 함께 수정. 백그라운드 갱신은 WorkManager **6시간** 주기이고 순위 계열 위젯이 실제로 설치돼 있을 때만 돈다(`main.dart` 의 `fmkWidgetBackgroundDispatcher` → `FmkHomeWidgetBridge.refreshStandingsFromNetwork`). 2셀 폭(<180dp)이면 콤팩트 레이아웃으로 자동 전환(`onAppWidgetOptionsChanged`)
- `android/.../FmkStandingsWidgetProvider.kt` — 챔피언십 순위 위젯. 토글이 아니라 드라이버/팀 **별도 위젯 종류**로 나뉘고(레이아웃의 `toggle_group_standings` 는 항상 GONE), Top 5(콤팩트는 Top 3) + ▲▼ 변동. 데이터 키 `stDriver*`/`stTeam*` 은 브리지 `_saveStandingsPayload` 와 수동 동기화, 순위 fetch 는 6시간 캐시(서버 갱신 주기와 동일, 실패 시 번들 정적 순위)
- **MY PICKS(MY DRIVER / MY TEAM)** — 설정 화면의 `widgets/my_picks_card.dart`(타일 + 그리드 선택기)에서 고르고 `services/my_picks_controller.dart`(prefs `my_driver_code`=TLA, `my_team_ko`=teamKo)에 저장. 브리지 `_saveMyPicksPayload` 가 순위 행과 결합해 `myDriver*`/`myTeam*`(+`myTeamD1/D2*`) 키를 저장 — Android `FmkMyPicksWidgetProviders.kt`(`FmkMyDriverWidgetProvider`/`FmkMyTeamWidgetProvider`, 레이아웃 `widget_fmk_my_driver/team.xml`)·iOS `FmkMyPicksWidgets.swift`(kind `FmkMyDriverWidget`/`FmkMyTeamWidget`)와 수동 동기화. 표기는 TLA/영문(`data/drivers.dart` `driverNameEnByCode`, `data/teams.dart` 약어/영문명), 팀 컬러 스트라이프+글로우. 미설정 위젯 탭 → `fmkwidget://mypicks` → 설정 화면(app.dart)
- **위젯 테마**(설정 › 위젯: 다크/라이트/시스템, 기본 다크) — `services/widget_theme_controller.dart` → 브리지 `updateTheme` 이 `widgetThemeMode` 키 저장. Android `FmkWidgetTheme.kt`(`forFmkWidgetTheme`/`applyFmkWidgetBackground` — 새 Provider 는 모든 정적 @color 텍스트를 이 Context 로 `setTextColor` 해야 함), iOS `FmkTheme.swift` `fmkWidgetScheme()`(각 위젯 뷰 최상위에 1회)
- `ios/FmkWidgets/` — iOS WidgetKit 익스텐션. **앱 본체·익스텐션 모두 최소 iOS 15**(2026-08-11 `2fb491d` 에서 14 → 15, Podfile 과 pbxproj 양쪽). 현재 번들에 등록된 건 `FmkHomeWidget`(일정 전용, 네트워크 없음) + 순위 2종 + MY PICKS 2종 + Live Activity. `FmkSplitWidgets.swift` 의 `FmkScheduleWidget`·`FmkLiveResultWidget` 은 라이브 제거와 함께 **등록 해제**했고 코드만 남겨 뒀다(되살리는 법은 그 파일 머리 주석). 데이터는 App Group `group.kr.formulamagazine.fmk`(UserDefaults) 공유. 라이브 fetch(`FmkLive.swift` — 표시 정책 포팅본이므로 라이브 규칙 변경 시 함께 수정)는 이제 **애플워치에서만** 쓴다. 위젯 kind 문자열·데이터 키는 브리지와 수동 동기화. Xcode 타깃 빌드 설정은 Generated.xcconfig 를 base 로 사용(버전 자동 동기화). 위젯 탭 딥링크는 `fmkwidget://…?homeWidget`(iOS 는 `homeWidget` 쿼리 파라미터 필수)
- `ios/FmkWatch/`(워치 앱) · `ios/FmkWatchWidgets/`(컴플리케이션) — 애플워치(watchOS 10+, SwiftUI 전용, Flutter 미지원). **데이터 경로**: App Group 은 아이폰↔워치 간 공유되지 않으므로 브리지가 저장을 마친 뒤 `MethodChannel('fmk/watch').sync` → `Runner/FmkWatchSync.swift` 가 App Group 전체를 WatchConnectivity(`updateApplicationContext` + 컴플리케이션 활성 시 `transferCurrentComplicationUserInfo`)로 전송 → 워치 `FmkWatchSessionBridge.swift` 가 같은 키로 워치 App Group 에 저장 후 `reloadAllTimelines`. 덕분에 `FmkWidgets/FmkLive.swift`·`FmkPayloadStore.swift` 를 워치 타깃이 그대로 공유한다(타깃 멤버십만 추가). 팔레트는 `FmkWatchTheme.swift`(다크 고정 — FmkTheme 은 UIKit 동적 색이라 워치 불가). 컴플리케이션 kind: `FmkWatchSchedule`(일정·라이브 자동 전환, 세션 창에서만 live.json fetch) / `FmkWatchDriverStandings` / `FmkWatchMyDriver`, 패밀리 inline·circular·rectangular·corner. 번들 ID `kr.formulamagazine.fmk.watchkitapp(.FmkWatchWidgets)`. **워치 실기기는 arm64_32(Int 가 32비트)** — epoch 밀리초를 `integer(forKey:)` 로 읽거나 `[String: Int]` 로 캐스팅하면 잘리거나 통째로 실패한다(시뮬레이터는 64비트라 재현 불가). `FmkPayloadStore.swift` 의 `epoch()`(double 로 읽기)·`colorMap()`(NSNumber 경유)이 그 대응이니 큰 정수를 새로 읽을 땐 같은 방식을 쓸 것. 검증은 `xcrun swiftc -typecheck -target arm64_32-apple-watchos10.0` 로 가능. 사진 시계 등 작은 슬롯(원형·코너·인라인)의 텍스트는 축약 라벨(`fmkShortSessionName`, TLA, 당일 "오늘")을 쓴다 — 긴 한글 라벨은 잘린다. 빌드: 워치 타깃이 Runner 에 임베드되어 **iOS 빌드에도 watchOS 시뮬레이터 플랫폼 설치가 필요**(`xcodebuild -downloadPlatform watchOS`), `flutter build ios --simulator` 는 `-d <시뮬레이터 UDID>` 필수
- `test/` — 주제별로 파일을 나눈다(현재 24개). 화면: app_navigation / app_ui / tablet_layout / home_hero / home_cards / home_recent_result / live_center_screen / standings_detail / news_screen / my_picks. 로직: live_session_model / live_session_controller / live_session_label / live_widgets / standing_insights. 서비스: news_repository / race_results_repository / standings_repository / notification_settings_controller / widget_theme_controller / app_theme_controller / fmk_home_widget_bridge / live_session_service. 규약: app_version(앱 정보 화면 버전 표기 `lib/app_version.dart` 가 pubspec `version:` 과 어긋나면 실패 — 릴리스 때 두 곳을 같이 올릴 것)

## 컨벤션

- **색상/앱 테마**: 팔레트는 전부 `lib/theme/app_colors.dart`. 2026-08 부터 **앱 테마 3벌**(설정 › 테마) — dark(기본, 종전 디자인과 비트 동일)/light(흰 배경+레드)/fmk(FMK 브랜드: 검정+옐로). `AppColors.*` 는 `static const` 가 아니라 **현재 `AppPalette` 를 읽는 getter** 라서 ① `const` 위젯 안에 넣을 수 없고 ② 새 토큰은 세 팔레트 모두에 값을 정의해야 한다. 전환은 `services/app_theme_controller.dart`(prefs `app_theme_mode`) → app.dart 가 MaterialApp 을 **키 교체로 리마운트**(내비 스택이 사라져 설정 화면은 `consumeReopenSettings()` 로 복원). 새 hex 리터럴을 화면에 직접 넣지 말고 팔레트 토큰을 추가할 것. 액센트 단색 배경(LIVE 필, 레드/옐로 버튼) 위 텍스트는 `AppColors.onAccent`(FMK 옐로 위엔 검정), "진짜 흰색"은 `pureWhite`(themed `white` 는 라이트에서 잉크색이 된다). **노란색 금지 규칙은 dark/light 테마의 일반 강조에만 적용**(FMK 테마 액센트와 의미색 `tyreMedium`/`flagYellow` 는 예외). 타이어·깃발·날씨·타이밍 퍼플 등 의미색은 테마와 무관한 const(소프트 컴파운드는 `red` 가 아니라 `tyreSoft`, 적기는 `flagRed`). 홈 위젯/워치 팔레트는 별개(네이티브)라 앱 테마의 영향을 받지 않는다
- **시간**: 모든 표시 시간은 KST 고정(UTC+9 수동 변환). 세션 지속시간 추정은 `races.dart`의 `_sessionDurations`(레이스 120분 = F1 2시간 제한)
- 주석은 한국어로, "왜"(규칙의 근거, 웹 원본 출처)를 남긴다
- 라이브 표시 정책(중요 규칙): Practice/Qualifying은 랩타임만 표시(없으면 '—', gap 폴백 금지, 컬럼 라벨 'BEST'), Race/Sprint는 interval만(없으면 '—' — gapToLeader 폴백 금지, 컬럼 라벨 'INTERVAL'). 세션 종료 노출 기한은 "다음 세션 30분 전까지(마지막 세션은 +1시간)". 퀄리파잉만 세그먼트(Q1/Q2) 사이 ended를 LIVE로 보정
- 검증: 변경 후 `flutter analyze` + `flutter test`, 위젯/알림 등 네이티브 변경은 `flutter build apk --debug`까지

## 외부 비용 제약 (중요)

- Vercel 팀 `formula-magazine-korea` 는 **무료 플랜(엣지 요청 월 100만)** 이고, 초과하면 프로젝트가 자동 일시정지된다. 2026-08-24 기준 75% 소진.
- 릴리스 빌드의 라이브 URL 기본값은 Railway 직결이 아니라 **Vercel `/api/live`** 다(`lib/services/live_session_service.dart` 의 `kLiveJsonUrl` — 한국 지연 500ms→65ms 목적). 즉 **라이브 폴링 = Vercel 비용**. `/api/standings`·`/api/race-results`·`/api/news` 도 전부 Vercel.
- 엣지 캐시 히트도 엣지 요청으로 계산되므로 `s-maxage` 를 늘려도 요청 수는 안 줄어든다. **클라이언트 호출 자체를 줄이는 것만 효과가 있다.**
- 그래서 폴링/백그라운드 동작을 건드리는 변경은 반드시 "디바이스당 하루 몇 건" 으로 환산해서 판단할 것. 2026-08 이전엔 앱이 백그라운드에서도 20초마다 폴링해 디바이스당 하루 약 4,320건을 썼다(현재는 포그라운드 한정 + 세션 창 밖 5분).
- **라이브는 2026-08-24 이전 완료** — `live.formulamagazine.kr`(Cloudflare 무료, 주황 구름 → Railway collector). 구성·점검법·주의사항은 `docs/live_cdn_migration.md`. **`formulamagazine.kr` 네임서버가 Cloudflare 로 옮겨졌고 이 도메인에 다음(Daum) 메일이 붙어 있으니**, DNS 를 손볼 일이 생기면 그 문서의 레코드 표를 먼저 볼 것. 순위·결과·소식은 클라이언트 캐시(6시간/30분)가 있어 Vercel 무료로 충분하니 옮기지 않았다.
- 측정값(2026-08-24): 이전 후 **0.15초 / 4.1 KB / cf-cache-status HIT**(직결은 0.55초·29.5 KB). Cloudflare 가 응답을 자동 압축하므로 collector gzip 은 선택 사항이다. collector 는 `Cache-Control: ... s-maxage=5 ...` 를 이미 보내고 있고, **HEAD 요청에는 404 를 준다** — 점검은 `curl -s -D - -o NUL` 로 할 것.
- 레이스/스프린트 중에는 **10초** 폴링(`LiveSessionController.racePollInterval`). **기본값이 켜짐**이라 플래그 없이 빌드해도 적용된다 — 되돌릴 때만 `--dart-define=LIVE_FAST_POLL=false`. 원래 꺼 두었던 이유는 Vercel 요청 비용이었고 Cloudflare 이전으로 사라졌다. 연습/퀄리는 랩타임 갱신이 드물어 20초를 유지한다.

## 미해결 사항

- iOS·애플워치는 **2026-08-23 빌드 38(0.1.5)로 App Store 에 출시됐다** — IPA 에
  `Payload/Runner.app/Watch/FmkWatch.app`(+ `PlugIns/FmkWatchWidgets.appex`)이 서명까지 포함돼 나갔다.
  실기기에서의 위젯·알림·컴플리케이션 동작은 아직 체계적으로 점검하지 않았다
  (0.1.7 에 워치 실기기 전용 32비트 버그 수정이 들어갔으니 점검은
  `docs/watch_device_checklist.md` 체크리스트로 할 것)
- Wear OS 미착수

## 업데이트 권장 팝업 (릴리스 절차에 포함)

- 앱은 시작 시 하루 1회 `https://live.formulamagazine.kr/app-version.json`(collector
  `data/app-version.json`, Cloudflare 5분 캐시 — Vercel 미사용)을 받아 자기 빌드 번호와
  비교한다(`lib/services/app_update_service.dart`, 팝업은 `app.dart` `_maybePromptAppUpdate`).
  latest 보다 낮으면 "나중에" 가능한 권장 팝업, minSupported 미만이면 닫을 수 없는 강제 팝업.
  "나중에"를 누른 버전은 다시 묻지 않고, 더 새 버전이 나오면 다시 묻는다.
- **스토어에 새 버전이 반영된 뒤** 자매 저장소에서 `npm run app-version -- android 47`
  (iOS 는 `-- ios 0.1.9`) → commit → push → Railway 재배포. 심사 전에 올리면 사용자가 없는
  버전으로 헛걸음하므로 **자동화하지 않는다**. `--min N` 은 심각 버그 때만(강제 업데이트).

## 릴리스 서명

- release 빌드는 실제 업로드 키로 서명됨(CN=Minuk Kim / Formula Magazine Korea).
  키스토어 `C:/Users/2001m/upload-keystore.jks`(별칭 `upload`), 자격증명은
  `android/key.properties`(gitignore 대상, 저장소에 없음). key.properties 가 없는
  머신에서 `flutter build appbundle` 하면 서명 단계에서 실패하니, 릴리스 빌드는
  이 파일이 있는 환경에서만 한다(디버그 빌드는 무관). **Mac 에는 이 파일이 없다**
  — 안드로이드 릴리스는 Windows 머신에서, iOS 아카이브는 Mac 에서 한다.
