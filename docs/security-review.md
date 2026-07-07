# 보안 점검 기록 (2026-07-07)

앱의 실제 공격 표면 기준으로 저장소 전체를 수동 점검한 결과. 자동 스캐너
리포트의 오탐 판정 근거도 함께 기록한다.

## 점검 범위와 결과 요약

| 영역 | 결과 |
|---|---|
| 비밀(키/비밀번호) 유출 — 현재 파일 + git 전체 이력 | ✅ 없음 (`key.properties`/`*.jks` gitignore, 이력에도 미존재) |
| 네트워크 — cleartext 허용 여부 | ✅ 허용 설정 없음(Android 기본 차단). 프로덕션 live.json 은 HTTPS |
| 외부 URL 실행(url_launcher) | ✅ 상수 URL만 사용(인스타그램/메일/F1DB), `externalApplication` 모드. 사용자 입력 URL 실행 없음 |
| 신뢰 불가 입력 파싱(live.json) | ✅ 전면 방어적 파싱(타입 검사 + try/catch) + **리스트 상한 40 추가**(아래) |
| 의존성 버전 | ✅ direct 의존성 전부 최신 (`flutter pub outdated`) |
| release 서명/디버그 플래그 | ✅ 업로드 키 서명, debuggable 미설정(기본 false) |

## 이번에 적용한 보완

1. **live.json 파서 리스트 상한** (`lib/services/live_session_service.dart`)
   — collector 가 오염되거나 응답이 위조돼 초대형 배열이 와도 최대 40명까지만
   파싱한다(무제한 자원 소비 방어). 회귀 테스트 포함.
2. **릴리즈 난독화 권장 명령 문서화** (README) —
   `--obfuscate --split-debug-info=build/symbols`.

## 확인 후 수용한 위험 (조치 불필요 판단)

- **`android:allowBackup` 기본값(true)**: 백업 대상이 알림 토글/위젯 표시
  상태 같은 비민감 데이터뿐이라 유지. 민감 데이터를 저장하게 되면 재검토.
- **위젯 리시버의 커스텀 토글 액션**: `FmkHomeWidgetProvider` 는 위젯 특성상
  exported 여야 하고, 커스텀 액션(SHOW_SCHEDULE/SHOW_LIVE)을 다른 앱이 쏠 수
  있다. 영향이 "위젯 화면 토글"뿐인 순수 UI 상태라 수용.
- **debug 기본 URL(`http://localhost:8787`)**: 로컬 개발 전용이고 릴리즈
  빌드는 dart-define 으로 HTTPS 주소를 주입한다.

## 자동 스캐너 오탐 판정 기록

- `windows/flutter/generated_plugin_registrant.h` — CWE-20 (HIGH):
  **오탐.** Flutter 자동 생성 파일. 외부 입력이 존재하지 않고(컴파일 타임에
  링크된 플러그인을 시작 시 1회 등록), 수정해도 다음 빌드에서 덮어써진다.
- `windows/runner/utils.h` — CWE-20 (HIGH): **오탐(이미 완화됨).** 선언 전용
  헤더이며 구현부(utils.cpp)는 null 검사, `wcsnlen` 길이 상한,
  `WC_ERR_INVALID_CHARS`(비정상 UTF-16 거부), 버퍼 크기 검증을 모두 포함.
  입력원은 로컬 커맨드라인 인자로 원격 벡터 없음.
- 공통 배경: `windows/` 는 개발 편의용 데스크톱 러너이며 배포 대상이 아니다.
  스캐너가 계속 지적하면 폴더 제거도 선택지.

## 다음 배포 전 체크리스트

- [ ] keystore/비밀번호 오프라인 백업 확인
- [ ] (선택) keystore 비밀번호 교체 — 대화/스캐너 로그에 노출된 적 있음
- [ ] 릴리즈 빌드에 `--obfuscate --split-debug-info` 적용, 심볼 보관
