# 비아 포뮬러(구 포매코) Flutter 앱 1차 MVP 상태 정리

## 1. 앱 개요

비아 포뮬러 Flutter 앱은 포뮬러 매거진 코리아(Formula Magazine Korea)의 F1 팬용 일정 앱 MVP입니다.

현재 목표는 2026 시즌 F1 일정을 기준으로 사용자가 다음 그랑프리, 세션 시간, 그랑프리 상세 정보, 챔피언십 순위, 직관 가이드, 라이브 순위를 한 앱에서 확인할 수 있게 만드는 것입니다.

현재 버전은 상용 배포용 완성본이 아니라, 팀원·멘토·내부 시연용 1차 MVP입니다.

---

## 2. 프로젝트 경로

### Flutter 앱

```powershell
C:\Users\2001m\fmk_app
```

### 기존 웹 프로젝트 / 라이브 collector

```powershell
C:\Users\2001m\fmk-f1-calendar
```

---

## 3. 현재 구현 완료 기능

### 기본 화면

* 홈 화면
* 일정 화면
* 그랑프리 상세 화면
* 드라이버/컨스트럭터 순위 화면
* 설정 화면
* 직관 화면
* 하단 탭: 홈 / 일정 / 순위 / 직관
* 홈 우측 상단 설정 진입

### 데이터 이식

* 2026 시즌 그랑프리 일정
* 세션 일정
* 그랑프리 상태
* 서킷 정보
* 서킷 레이아웃 이미지
* 레이스 결과 / Top 3
* 드라이버 순위
* 컨스트럭터 순위
* 팀 컬러
* 국가 국기 매핑

### 웹 UI 이식

기존 Next.js 웹 앱의 UI를 Flutter로 최대한 비슷하게 이식했습니다.

완료된 화면:

* 홈 화면
* 일정 화면
* 그랑프리 상세 화면
* 순위 화면
* 설정 화면
* 직관 화면
* 하단 네비게이션
* 공통 카드 / 칩 / 팔레트

주요 공통 위젯:

* `AppCard`
* `AppChip`
* `BottomNav`
* `HeroCard`

### 홈 화면 현재 구성

홈 화면은 다음 구조로 정리되어 있습니다.

1. 라이브 Top 3 카드

   * 라이브 데이터가 있을 때만 표시
   * 탭 시 해당 그랑프리 상세 화면으로 이동

2. 다음 그랑프리 히어로 카드

   * 다음 그랑프리 정보 표시
   * 히어로 카드 내부에 다음 세션 박스 포함
   * 탭 시 해당 그랑프리 상세 화면으로 이동

3. 이번 주말 일정 카드

   * 해당 그랑프리의 전체 세션 일정 표시

제거한 카드:

* 다음 세션 별도 카드
* 시즌 진행 상황 카드
* 전체 일정 보기 카드

---

## 4. 라이브 기능 구현 상태

현재 Flutter 앱은 직접 SignalR에 연결하지 않습니다.
기존 웹 프로젝트의 live collector가 제공하는 `live.json`을 fetch하는 방식입니다.

### 구현 완료

* `live.json` fetch
* 20초 주기 polling
* 홈 라이브 Top 3 카드
* 상세 화면 라이브 순위 패널
* 라이브 카드 탭 시 해당 그랑프리 상세 이동
* `raceId` 기반 그랑프리 매칭
* KST 기준 업데이트 시각 표시
* 국가 국기 표시
* `live / ended / expired` 상태 처리
* 종료 후 30분 이내 결과 표시
* `visibleUntil` 이후 자동 숨김
* 네트워크 실패 시 마지막 정상 스냅샷 75초 유지
* collector가 꺼져 있어도 앱 크래시 없음

### 관련 Flutter 파일

```text
lib/models/live_session.dart
lib/services/live_session_service.dart
lib/services/live_session_controller.dart
lib/widgets/live_session_builder.dart
lib/widgets/home_live_top_three_card.dart
lib/widgets/race_live_classification_panel.dart
```

### live.json endpoint 설정

```dart
const String kLiveJsonUrl = String.fromEnvironment(
  'LIVE_JSON_URL',
  defaultValue: 'http://localhost:8787/live.json',
);
```

기본값은 Windows/Chrome 개발용 `localhost`입니다.
Android emulator에서는 `10.0.2.2`를 사용해야 합니다.

---

## 5. 라이브 collector mock 모드

웹 프로젝트의 collector는 mock 모드를 지원합니다.

### 실행 위치

```powershell
cd C:\Users\2001m\fmk-f1-calendar
```

### live mock

```powershell
$env:LIVE_MOCK_MODE="live"
npm run live-collector:dev
```

예상 동작:

* 홈 라이브 Top 3 카드 표시
* 일본 그랑프리 상세 화면에서 라이브 순위 패널 표시
* status = live
* raceId = japan-2026
* topThree = 3명
* classification = 6명

### ended mock

```powershell
$env:LIVE_MOCK_MODE="ended"
npm run live-collector:dev
```

예상 동작:

* 종료 후 30분 이내 상태로 처리
* 홈/상세 라이브 UI 표시
* 최종 결과처럼 표시

### expired mock

```powershell
$env:LIVE_MOCK_MODE="expired"
npm run live-collector:dev
```

예상 동작:

* visibleUntil이 지난 상태
* 홈/상세 라이브 UI 숨김
* 정적 화면은 정상 유지

### mock 모드 해제

```powershell
Remove-Item Env:LIVE_MOCK_MODE
```

mock 모드가 없으면 실제 SignalR 연결을 시도합니다.

---

## 6. Flutter 앱 실행 방법

### Chrome 실행

```powershell
cd C:\Users\2001m\fmk_app
flutter run -d chrome --dart-define=LIVE_JSON_URL=http://localhost:8787/live.json
```

### Android Emulator 실행

Android emulator에서는 PC의 localhost를 `10.0.2.2`로 접근합니다.

```powershell
flutter run -d emulator-5554 --dart-define=LIVE_JSON_URL=http://10.0.2.2:8787/live.json
```

### 실제 Android 기기 실행

PC와 같은 네트워크에 연결한 뒤, PC의 내부 IP를 사용합니다.

```powershell
flutter run --dart-define=LIVE_JSON_URL=http://192.168.0.10:8787/live.json
```

IP 주소는 실제 PC 환경에 맞게 변경해야 합니다.

### Windows desktop 실행 관련

현재 Windows desktop 실행은 Visual Studio C++ toolchain이 없으면 실패합니다.

오류 예시:

```text
Unable to find suitable Visual Studio toolchain.
```

Windows desktop 앱으로 실행하려면 Visual Studio 2022 또는 Build Tools for Visual Studio에서 아래 워크로드가 필요합니다.

```text
Desktop development with C++
```

현재 MVP 확인은 Chrome으로 충분히 가능합니다.

---

## 7. 검증 완료 사항

현재까지 아래 검증을 통과했습니다.

```powershell
dart format lib test
flutter analyze
flutter test
```

상태:

* `flutter analyze` 통과
* `flutter test` 통과
* 현재 테스트 7개 통과
* 주요 화면 네비게이션 테스트 통과
* 라이브 렌더링 테스트 통과
* 라이브 카드 탭 이동 테스트 통과
* `live / ended / expired` 상태 테스트 통과
* KST 업데이트 시각 테스트 통과
* 국기 매핑 테스트 통과
* parseLiveJson 테스트 통과

---

## 8. 수동 QA 체크리스트

### collector mock live 상태

1. collector 실행

```powershell
cd C:\Users\2001m\fmk-f1-calendar
$env:LIVE_MOCK_MODE="live"
npm run live-collector:dev
```

2. Flutter 실행

```powershell
cd C:\Users\2001m\fmk_app
flutter run -d chrome --dart-define=LIVE_JSON_URL=http://localhost:8787/live.json
```

3. 확인할 것

* 홈 라이브 카드가 표시되는지
* 홈 라이브 카드 탭 시 일본 그랑프리 상세로 이동하는지
* 일본 그랑프리 상세 화면에 라이브 순위 패널이 표시되는지
* 전체 순위 보기 / 접기가 정상인지
* 업데이트 시간이 `HH:mm KST`로 표시되는지

### collector 끊김 테스트

1. live mock 상태에서 앱에 라이브 카드가 뜬 것을 확인
2. collector 터미널에서 `Ctrl + C`
3. 기대 동작

* 라이브 UI가 바로 사라지지 않음
* 마지막 정상 snapshot을 약 75초 유지
* 75초 이후에는 숨김 처리
* 앱 크래시 없음

### expired 상태

1. collector를 expired mock으로 실행

```powershell
$env:LIVE_MOCK_MODE="expired"
npm run live-collector:dev
```

2. 기대 동작

* 홈 라이브 카드 숨김
* 상세 라이브 패널 숨김
* 정적 화면 정상 유지

---

## 9. 데모 시나리오

팀원 또는 멘토에게 보여줄 때는 아래 순서로 시연합니다.

1. 앱 실행

2. 홈 화면 확인

   * 다음 그랑프리
   * 히어로 내부 다음 세션
   * 이번 주말 일정

3. 일정 탭 확인

   * 전체 / 예정 / 진행중 / 종료 필터
   * 종료된 그랑프리가 하단으로 내려가는 구조

4. 그랑프리 상세 화면 확인

   * 서킷 레이아웃 이미지
   * 레이스 시작 카드
   * 세션 일정
   * 서킷 정보
   * 레이스 결과 / Top 3
   * F1DB / Circuit layouts 출처

5. 순위 화면 확인

   * 드라이버 순위
   * 컨스트럭터 순위
   * 포인트 막대
   * F1DB 출처

6. 설정 화면 확인

   * 캘린더 추가 안내
   * 알림 예정 안내
   * 인스타그램 / 문의 / 제보 / F1DB 링크
   * 앱 정보

7. 직관 화면 확인

   * GUIDE IN PROGRESS
   * 일본 / 중국 / 싱가포르 그랑프리 직관 가이드 준비 중

8. live mock 실행 후 라이브 시연

   * 홈 라이브 Top 3 카드
   * 라이브 카드 탭
   * 일본 그랑프리 상세 라이브 순위 패널
   * 전체 순위 보기 / 접기

---

## 10. 아직 미구현 또는 후순위 기능

현재 MVP에서 아직 구현하지 않은 기능입니다.

### 라이브 관련

* 실제 F1 라이브 세션 중 end-to-end 검증
* 실제 classification 20명 데이터 확인
* 라이브 펄스 / 글로우 애니메이션
* 실시간 데이터 지연/오류 상태 표시 강화
* 앱 종료 후 백그라운드 라이브 유지

### 알림 / 캘린더

* 세션 시작 전 푸시 알림 실제 구현
* 레이스 시작 전 푸시 알림 실제 구현
* 기기 캘린더 추가 실제 구현
* OS 권한 처리
* 알림 시간 설정 저장

### 앱 배포

* Android 앱 아이콘 적용
* iOS 앱 아이콘 적용
* 앱 이름/패키지명 최종 정리
* Android 권한 확인
* cleartext HTTP 개발 설정 정리
* release build
* Play Store / App Store 배포 준비

### 기타

* 즐겨찾기 그랑프리
* 위젯
* 기사/인스타그램 콘텐츠 연동
* 예측/판타지 기능
* 직관 여행 상품 상세화
* 로그인/계정 기능

---

## 11. 현재 MVP 기준 결론

현재 앱은 1차 MVP 기준으로 다음을 충족합니다.

* F1 일정 앱의 기본 정보 구조 완성
* 웹 UI 기반 Flutter 화면 이식 완료
* 주요 정적 화면 QA 완료
* live.json 기반 라이브 UI 표시 가능
* mock live / ended / expired 테스트 가능
* 팀원·멘토에게 보여줄 수 있는 데모 가능

다만 아직 상용 배포 단계는 아닙니다.
실제 라이브 세션 검증, 알림/캘린더 실제 구현, Android/iOS 권한 및 배포 설정은 후속 작업으로 남아 있습니다.
