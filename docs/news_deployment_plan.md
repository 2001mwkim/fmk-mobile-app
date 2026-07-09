# 소식(News) 데이터 배포 계획

`/api/news` 실서비스 전에, 뉴스 데이터(`news.json`)를 배포 환경에서 어떻게
유지·갱신할지 정리한 문서. 2026-07-08 기준 조사 결과와 권장안.

## 현재 배포 구조 (조사 결과)

| 구성요소 | 배포 위치 | 근거 |
|---|---|---|
| 웹앱 (Next.js, `/api/news` 포함) | **Vercel — 서버리스** | `app/layout.tsx` 에서 `@vercel/analytics` 사용 중, README 의 Vercel 배포 안내, 서버형 배포 설정 파일(Dockerfile/railway.toml 등) 없음 |
| 라이브 collector (`live.json`) | **Railway — 장수 Node 프로세스** | `https://live-production-c03d.up.railway.app/live.json`, README 에 "서버리스로 배포 금지" 명시 |
| 뉴스 collector | **아직 로컬 수동 실행만** | `npm run news-collector` → `.news/news.json` |

## 현재 구조의 문제점

1. **`.news/` 는 gitignore** → Vercel 배포 번들에 `news.json` 이 없다.
   배포 직후 `/api/news` 는 (설계대로) 크래시 없이 **빈 items** 를 돌려주지만,
   수동으로 갱신할 방법도 없다 — 서버리스 함수의 파일시스템은 임시적이고
   요청 간에 유지되지 않는다.
2. 뉴스 collector 를 주기 실행하는 스케줄러가 아직 없다.

**결론: `.news/news.json` 로컬 파일 방식(A)은 현재 배포 구조(Vercel)에서
실서비스에 부적합하다.** 로컬 파일은 개발/테스트 전용이다.

## 저장 방식 비교

| 방식 | 내용 | 판단 |
|---|---|---|
| **A. 로컬 파일 유지** | cron 으로 collector 실행, `/api/news` 가 로컬 파일 읽기 | ❌ Vercel 서버리스에선 불가. 웹앱을 VPS 로 옮기지 않는 한 선택지 아님 |
| **B. 외부 소스 사용** | collector 가 결과를 외부에 두고 `/api/news` 가 원격으로 읽기 | ✅ **권장** — 아래 상세 |
| **C. 정적 파일 배포** | 빌드 전에 collector 실행 → `public/news.json` 포함 | ⚠️ 백업안. 빌드할 때만 갱신되므로 최신성이 떨어짐(뉴스에 부적합). 임시 데모용으로만 |

## 권장안: B — 원격 URL 소스 (구현 완료) + Railway collector 확장 (다음 작업)

이 프로젝트에는 이미 같은 문제를 푼 선례가 있다: **`/api/live` 는
`LIVE_COLLECTOR_URL` 환경변수로 Railway collector 의 JSON 을 원격 fetch 한다.**
뉴스도 같은 패턴을 쓴다.

### 1단계 — `/api/news` 원격 소스 지원 (✅ 이번에 구현)

`app/api/news/route.ts` 가 데이터 소스를 순서대로 시도한다:

1. **`NEWS_JSON_REMOTE_URL`** (프로덕션) — JSON 을 돌려주는 URL 이면 무엇이든
   됨: Railway collector 호스트, 블롭 스토리지 공개 URL 등.
   **특정 스토리지 벤더에 묶이지 않는다.** 2.5초 타임아웃, 실패 시 폴백.
2. **`NEWS_JSON_PATH` 또는 `.news/news.json`** (개발/셀프호스팅) — 로컬 파일.
3. 둘 다 실패 → 빈 items 로 200 (앱은 빈 상태 카드 표시, 크래시 없음).

향후 스토리지 SDK 직접 접근이 필요해지면 같은 시그니처
(`() => Promise<NewsFeedJson | null>`)의 로더를 체인에 추가하면 된다
(route.ts 의 TODO 주석 참고).

### 2단계 — Railway collector 에 뉴스 수집 통합 (✅ 구현 완료)

이미 떠 있는 장수 프로세스(live collector)에 통합했다. 추가 인프라/비용 0,
기존 배포 파이프라인(main push → Railway) 재사용.

- **주기 수집**: `scripts/news-scheduler.ts` — 프로세스 시작 직후 1회 +
  `NEWS_COLLECT_INTERVAL_MINUTES`(기본 30분) 간격으로 RSS 수집 + (활성 시)
  AI 브리핑 실행. `0` 이하로 설정하면 뉴스 수집 비활성.
- **메모리 캐시**: 마지막으로 **성공한**(1건 이상) 피드만 메모리에 유지.
  수집 실패(예외/0건) 시 기존 성공 결과를 절대 덮어쓰지 않고 유지한다.
  성공 시 `.news/news.json` 파일도 갱신(개발/디버깅용).
- **서빙**: live collector HTTP 서버에 `/news.json` 추가
  (`scripts/signalr-live-collector.ts`). 계약 형태 그대로, 수집 전이면
  200 + 빈 items, CORS 는 live.json 과 동일(`*`), 캐시는
  `public, max-age=0, s-maxage=120, stale-while-revalidate=300`.
- **안전장치**: 수집 함수는 어떤 경우에도 throw 하지 않아 live collector
  본연의 동작(SignalR/live.json)을 죽이지 않는다.

> 참고: CommonJS 빌드(`npm run build:live-collector`) 호환을 위해
> `news-rss-collector.ts` 의 `import.meta` 사용을 제거했다(경로는
> `process.cwd()` 기준, CLI 판별은 `process.argv[1]` 정규식).

- **(보류) 후보 2: 블롭 스토리지 + 외부 스케줄러** — Railway 통합으로 당장
  불필요. collector 프로세스가 여러 대로 늘거나 재시작 간 영속성이 필요해지면
  재검토.

### Flutter 앱 관점 (중요)

**앱은 저장 방식과 무관하게 `GET /api/news?limit=20&lang=ko` 만 호출한다.**
서버가 로컬 파일을 읽든 Railway 에서 가져오든 블롭에서 가져오든 앱 코드는
동일하다(직접 크롤링 없음 정책도 그대로). 서버 준비가 끝나면 앱 쪽 작업은
`NewsScreen` 기본 저장소를 `SampleNewsRepository` →
`HttpNewsRepository(baseUrl: ...)` 로 바꾸는 한 줄이 전부다.

## 환경변수 정리

**Railway (live collector — 뉴스 수집/서빙):**

| 변수 | 기본값 | 용도 |
|---|---|---|
| `NEWS_COLLECT_INTERVAL_MINUTES` | `30` | RSS 수집 주기(분). `0` 이하 = 뉴스 수집 비활성 |
| `NEWS_AI_INTERVAL_MINUTES` | `360` | **AI 호출 허용 주기(분)** — RSS 와 분리. 첫 수집에서는 1회 허용(캐시가 중복 과금 방지). `0` = 매 수집마다 허용 |
| `NEWS_AI_ENABLED` | (비활성) | `true` 일 때만 AI 제목/요약 생성 |
| `ANTHROPIC_API_KEY` | — | AI 용. 없으면 fallback 문구로 동작(missing_api_key 로그) |
| `NEWS_AI_MODEL` | `claude-haiku-4-5` | AI 모델. 기본은 가성비 Haiku — 품질 필요 시 상위 모델로 교체 |
| `NEWS_AI_MAX_CALLS_PER_RUN` | `20` | 실행당 실제 API 호출 상한(캐시 hit 제외). 초과분은 다음 실행에서 처리 |
| `NEWS_AI_DEBUG` | (비활성) | `true` 면 항목별 fallback 사유 상세 로그 |

비용 구조: 같은 기사는 hash 캐시(`.news/news-ai-cache.json`, 최근 800개)로
재호출하지 않으므로, 정상 상태에서 AI 비용은 "6시간마다 새 기사 수 × Haiku
호출 1회" 수준이다. 캐시 파일은 gitignore 대상이고 재배포 시 초기화된다
(재배포 직후 첫 실행에서 현재 20건만 다시 요약).

**Vercel (웹앱 — `/api/news`):**

| 변수 | 값 | 용도 |
|---|---|---|
| `NEWS_JSON_REMOTE_URL` | `https://<railway-domain>/news.json` | 원격 뉴스 소스. 프로덕션 필수 |

**로컬/개발:** `NEWS_JSON_PATH` 로 로컬 파일 경로 재정의 가능(기본 `.news/news.json`).

## 배포 후 확인 명령

```powershell
# 1) Railway — 수집/서빙 확인 (시작 후 첫 수집까지 수 초)
curl "https://<railway-domain>/news.json"        # items 20건 + titleKo 채워짐 기대
curl "https://<railway-domain>/live.json"        # 기존 라이브 동작 무변화 확인
curl "https://<railway-domain>/healthz"

# 2) Vercel — 원격 소스 연결 확인 (NEWS_JSON_REMOTE_URL 설정 후 재배포)
curl "https://<vercel-domain>/api/news?limit=20&lang=ko"
```

**Railway 로그에서 볼 것** (AI 문제 진단은 이 두 줄이면 충분):

```
[news-ai] config: NEWS_AI_ENABLED=true ANTHROPIC_API_KEY=true NEWS_AI_MODEL=claude-haiku-4-5 NEWS_AI_INTERVAL_MINUTES=360 NEWS_AI_MAX_CALLS_PER_RUN=20
[news-ai] total=20 cacheHits=0 aiCalls=20 success=20 fallback=0 | success=20
```

- `ANTHROPIC_API_KEY=false` → key 미설정 (전 항목 missing_api_key)
- `api_error=N` → key/크레딧/모델 문제. 같은 로그의
  `[news-ai] api_error model=... status=... type=...` 줄에서 원인 확인
  (401=key 오류, 404=모델명 오류, 429=rate limit 등)
- `interval_skip` → 정상(6시간 주기 밖의 새 기사, 다음 AI 실행 때 처리)

## 다음 작업 체크리스트

1. ✅ Railway collector 에 뉴스 수집 주기 실행 + `/news.json` 서빙 추가
2. ⬜ fmk-f1-calendar main 푸시 → Railway 재배포, `/news.json` 실데이터 확인
3. ⬜ Railway 환경에 `NEWS_AI_ENABLED=true` + `ANTHROPIC_API_KEY` 설정
   (미설정 시에도 동작은 하지만 브리핑이 fallback 문구)
4. ⬜ Vercel 환경에 `NEWS_JSON_REMOTE_URL` 설정 → `/api/news` 실데이터 확인
5. ✅ 앱 `NewsScreen` 기본 저장소를 `HttpNewsRepository` 로 교체 완료 —
   origin 은 `lib/services/news_repository.dart` 의 `kNewsApiBaseUrl`
   (기본 `https://www.formulamagazine.kr`, `--dart-define=NEWS_API_BASE_URL` 로 재정의)
