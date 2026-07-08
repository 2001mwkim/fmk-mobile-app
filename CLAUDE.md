# 비아 포뮬러 / Via Formula (fmk_app)

포뮬러 매거진 코리아(Formula Magazine Korea)가 운영하는 F1 팬용 Flutter 앱(Android 우선). 2026 시즌 일정·순위·직관 가이드·라이브 타이밍을 제공한다. 기존 Next.js 웹앱의 UI를 이식한 프로젝트라서, 화면 코드 주석에 웹 컴포넌트 출처(`components/...tsx`)와 색상 원본값을 적는 관례가 있다.

- **앱 표시명**: "비아 포뮬러" (영문 브랜드 "Via Formula", 스토어명 후보 "비아 포뮬러 - 일정·라이브·직관")
- **운영 브랜드**: "Formula Magazine Korea" / "포뮬러 매거진 코리아" — 출처·운영사 맥락에서는 이 이름을 유지한다
- 패키지/번들 ID(`kr.formulamagazine.fmk`)와 `fmk_*` 코드 식별자·파일명은 브랜드 변경과 무관하게 **변경 금지**

## 자매 저장소 (중요)

라이브 데이터는 별도 저장소의 collector가 제공한다:

- **웹/collector**: `C:\Users\2001m\fmk-f1-calendar` (GitHub: 2001mwkim/fmk-f1-calendar)
- collector 소스: `scripts/signalr-live-collector.ts` — F1 SignalR 피드 구독 → `live.json` HTTP 서빙
- **배포**: main 브랜치 push → Railway 자동 배포 (`https://live-production-c03d.up.railway.app/live.json`)
- 타입 동기화: 웹 `lib/live/types.ts` ↔ 앱 `lib/models/live_session.dart`는 **수동 복제** 관계다. collector가 내려주는 필드를 바꾸면 양쪽 모두 고칠 것.
- collector mock 모드: `LIVE_MOCK_MODE=live LIVE_MOCK_SESSION_TYPE=race|sprint|qualifying|practice npm run live-collector:dev` (+`LIVE_MOCK_NO_LAP_TIMES=1`로 랩타임 수신 전 상태 재현)
- 소식(뉴스) 수집기도 같은 저장소: `scripts/news-rss-collector.ts` (`npm run news-collector`) — 계약은 앱 `docs/news_api_contract.md`, 사용법은 `docs/news_rss_collector.md`. 앱 기본값은 아직 `SampleNewsRepository`(서버 미연동)

## 명령어

```powershell
# flutter가 PATH에 없으면: C:\Users\2001m\flutter\bin\flutter.bat
flutter analyze
flutter test
# 실기기용 빌드는 프로덕션 collector URL을 주입한다
flutter build apk --debug --dart-define=LIVE_JSON_URL=https://live-production-c03d.up.railway.app/live.json
# 로컬 collector 사용 시(dart-define 생략): 기본값 http://localhost:8787/live.json
```

## 구조

- `lib/data/` — 정적 데이터(2026 일정 `races.dart`, 결과 `race_results.dart`, 순위, 서킷, 국기, 팀 컬러) + **드라이버 매핑 `drivers.dart`**(코드→한글 이름/팀 액센트 — 시즌 라인업 변경 시 이 파일만 수정)
- `lib/models/live_session.dart` — 라이브 스냅샷 모델 + 표시 규칙(노출 기한, 세션 활성 판정 등 정책 함수 다수)
- `lib/services/` — `live_session_service`(live.json fetch/파싱), `live_session_controller`(폴링·유지 정책), `notification_*`(로컬 알림), `fmk_home_widget_bridge`(Android 홈 위젯 데이터 저장)
- `lib/screens/`, `lib/widgets/` — 화면/위젯. 순위 패널 공용 UI는 `widgets/classification_panel_parts.dart`, 트랙맵 SVG 렌더러는 `widgets/circuit_map.dart`
- `android/.../FmkHomeWidgetProvider.kt` — 홈 위젯(라이브↔일정 토글 포함). 위젯 데이터 키는 브리지와 Kotlin 양쪽에 문자열로 존재하므로 함께 수정
- `test/` — 주제별 분리(app_navigation / live_widgets / home_hero / live_session_model / live_session_controller / notification / bridge)

## 컨벤션

- **색상**: 팔레트는 전부 `lib/theme/app_colors.dart`의 `AppColors`. 새 hex 리터럴을 화면에 직접 넣지 말 것(웹 Tailwind 값만 옮겨온다는 원칙). **노란색 금지**(P1 강조도 레드 사용)
- **시간**: 모든 표시 시간은 KST 고정(UTC+9 수동 변환). 세션 지속시간 추정은 `races.dart`의 `_sessionDurations`(레이스 120분 = F1 2시간 제한)
- 주석은 한국어로, "왜"(규칙의 근거, 웹 원본 출처)를 남긴다
- 라이브 표시 정책(중요 규칙): Practice/Qualifying은 랩타임만 표시(없으면 '—', gap 폴백 금지), Race/Sprint는 interval/gap. 세션 종료 노출 기한은 "다음 세션 30분 전까지(마지막 세션은 +1시간)". 퀄리파잉만 세그먼트(Q1/Q2) 사이 ended를 LIVE로 보정
- 검증: 변경 후 `flutter analyze` + `flutter test`, 위젯/알림 등 네이티브 변경은 `flutter build apk --debug`까지

## 미해결 사항

- `android/app/build.gradle.kts`: release 서명이 debug key(스토어 배포 전 교체 필요)
- iOS는 프로젝트 준비만 된 상태(위젯/알림 iOS 검증 안 됨)
