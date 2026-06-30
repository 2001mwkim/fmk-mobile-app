# 포매코 F1 앱 — MVP 상태 메모

> 1차 MVP 현황 정리. 실무용 메모이며, 구현 상태를 있는 그대로 적는다.

## 1. 앱 개요

- **포매코 (FMK F1 캘린더)** — 한국 F1 팬용 일정/정보 앱.
- 2026 시즌의 **일정 · 그랑프리 상세 · 챔피언십 순위 · 라이브 현황**을 한국시간(KST) 기준으로 확인하는 MVP.
- 기존 Next.js 웹(`fmk-f1-calendar`) UI를 Flutter로 이식.
- 라이브 데이터는 Flutter가 SignalR에 직접 붙지 않고, 별도 collector가 만든 `live.json`을 폴링해서 표시한다.

## 2. 현재 구현 완료 기능

- **화면**
  - 홈: 라이브 카드(있을 때) → 다음 그랑프리 히어로 카드(내부에 다음/진행 중/최근 세션 박스 포함) → 이번 주말 일정 카드. 우상단 톱니 → 설정.
  - 일정: `전체 / 예정 / 진행중 / 종료` 필터, 그랑프리 카드 목록(NEXT 강조, 종료 컴팩트 카드), 카드 탭 → 상세.
  - 그랑프리 상세: 트랙맵(SVG, 없으면 placeholder) · 레이스 시작 · 세션 일정(타임라인) · 서킷 정보 · 레이스 결과 Top3(종료 시) · 출처.
  - 순위: 드라이버 / 컨스트럭터 탭 전환, 포인트 막대.
  - 설정: 일정 관리·알림(준비 중 안내), 인스타그램/문의/제보/F1DB 링크, 앱 정보.
  - 직관: GUIDE IN PROGRESS 안내 + 일본/중국/싱가포르 카드(준비 중).
- **공통 위젯/스타일**: `AppCard`, `AppChip`, `HeroCard`, `BottomNav`, `AppColors`/`AppTheme` (웹 팔레트 이식).
- **라이브 UI**
  - 홈 `HomeLiveTopThreeCard`, 상세 `RaceLiveClassificationPanel`(4위 이하 펼치기 포함).
  - `live.json` fetch → `LiveSessionSnapshot` 파싱(`LiveSessionService`), 20초 폴링(`LiveSessionController`).
  - **mock live / ended / expired** 대응: `live`/`ended`(종료 후 30분 이내) 표시, `expired`(visibleUntil 경과) 숨김.
  - **KST 업데이트 시각**: `업데이트 HH:mm KST` (ISO를 UTC+9로 변환).
  - **raceId 기반 라이브 상세 이동**: 홈 라이브 카드 탭 → `raceId`로 Race 조회 → 상세 이동(없으면 SnackBar).
  - 라이브 데이터 없거나 collector 꺼져 있으면 라이브 UI는 숨기고 정적 화면은 그대로 동작.
- **출처 표기**: 상세 `Circuit layouts: F1DB (CC BY 4.0)`, 순위 `데이터 출처: F1DB (CC BY 4.0)`, 설정 `F1DB · CC BY 4.0`.

## 3. 실행 방법

### Flutter 앱

```bash
cd C:/Users/2001m/fmk_app
flutter pub get
flutter run -d windows     # 또는 -d chrome / 연결된 기기
```

- live.json endpoint 기본값: `http://localhost:8787/live.json`
- 다른 주소가 필요하면 `--dart-define`으로 주입(`lib/services/live_session_service.dart`의 `kLiveJsonUrl` 한 곳에서 관리):

```bash
# Android emulator (localhost가 기기 내부를 가리킴)
flutter run --dart-define=LIVE_JSON_URL=http://10.0.2.2:8787/live.json

# 실제 기기 (PC LAN IP, 같은 네트워크)
flutter run --dart-define=LIVE_JSON_URL=http://192.168.0.10:8787/live.json
```

### live collector (mock)

웹 프로젝트(`C:/Users/2001m/fmk-f1-calendar`)에서 실행. `LIVE_MOCK_MODE`가 있으면 실제 SignalR에 연결하지 않고 mock `live.json`만 제공한다.

```bash
cd C:/Users/2001m/fmk-f1-calendar

LIVE_MOCK_MODE=live    npm run live-collector:dev   # 라이브 (홈 카드 + 상세 패널 표시)
LIVE_MOCK_MODE=ended   npm run live-collector:dev   # 종료 후 30분 이내 (표시됨)
LIVE_MOCK_MODE=expired npm run live-collector:dev   # 30분 경과 (라이브 UI 숨김)

npm run live-collector:dev                          # 미설정 → 실제 SignalR 연결
```

- mock raceId는 `japan-2026`(Flutter `races.dart`의 실제 id). 상세 패널은 일본 그랑프리 상세에서 노출.
- 응답 형태: `{ "snapshot": { ... }, "collector": { ... } }`
- 확인: `curl http://localhost:8787/live.json`

## 4. 미구현 / 후순위

- 푸시 알림 실제 구현 (현재 "앱 버전 예정" 안내만)
- 캘린더 실제 연동 (현재 "준비 중" 안내만)
- 실제 라이브 세션(SignalR 실데이터)으로 end-to-end 검증 — 지금은 mock/단위·위젯 테스트까지만 확인
- 네트워크 실패 시 마지막 스냅샷 유지 (현재는 실패 시 라이브 UI 숨김)
- 라이브 펄스/글로우 애니메이션 (현재 정적)
- 앱스토어/플레이스토어 배포 준비(아이콘, 서명, 권한, 스토어 메타)
- 라이브 시각의 명시적 Asia/Seoul 타임존 처리(현재 UTC+9 가산)

## 5. 데모 시나리오

1. (선택) collector를 `LIVE_MOCK_MODE=live`로 띄운다.
2. `flutter run`으로 앱 실행 → **홈** 확인(다음 그랑프리 히어로 + 내부 세션 박스 + 이번 주말 일정).
3. 하단 **일정** 탭 → `전체/예정/진행중/종료` 필터 전환 확인.
4. 일정 카드 탭 → **상세** 화면(트랙맵/레이스 시작/세션 일정/서킷 정보/출처, 종료 GP면 결과 Top3) 확인.
5. mock `live`가 켜져 있으면 **홈 상단 라이브 카드** 표시 확인.
6. 라이브 카드 탭 → 해당 그랑프리 **상세의 라이브 순위 패널**(Top3 + 4위 이하 펼치기) 확인.
7. (선택) collector를 `ended`/`expired`로 바꿔 표시/숨김 동작 확인.
8. **순위**(드라이버/컨스트럭터) · **설정**(외부 링크/준비 중) · **직관**(준비 중 카드) 확인.

## 6. 검증 상태

- `flutter analyze` — 이슈 없음
- `flutter test` — 통합 네비게이션 + 라이브 렌더/확장 + `parseLiveJson` + ended/expired + KST + 국기 + 라이브 탭 이동 통과
- collector mock(live/ended/expired)은 `curl`로 응답/`isDisplayable` 동작 확인
- 실기기/에뮬레이터 수동 실행 및 실데이터 검증은 미수행(후순위)
