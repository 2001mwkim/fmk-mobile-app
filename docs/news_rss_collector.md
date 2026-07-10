# 소식 RSS 수집기 (초안)

비아 포뮬러 앱 소식 탭에 내려줄 `news.json` 을 만드는 서버/스크립트 계층
수집기. **앱 저장소가 아니라 자매 저장소(fmk-f1-calendar)에 있다** —
live.json collector 와 같은 계층이다.

- 스크립트: `C:\Users\2001m\fmk-f1-calendar\scripts\news-rss-collector.ts`
- AI 브리핑 계층: 같은 폴더의 `news-ai-briefing.ts` (기본 비활성 — 아래 참고)
- API 라우트: `app/api/news/route.ts` (Next.js — `GET /api/news?limit=20&lang=ko`)
- 테스트: `scripts/` 의 `news-rss-collector.test.ts`, `news-ai-briefing.test.ts`,
  `news-api.test.ts`
- 출력 계약: 이 저장소의 [news_api_contract.md](news_api_contract.md)와 동일
  (앱 모델 `lib/models/news_item.dart` 와 **수동 동기화** — 필드 변경 시
  수집기·계약 문서·앱 모델을 함께 고칠 것)

## 목적과 정책 (중요)

- **앱은 크롤링하지 않는다.** RSS 수집은 이 스크립트에서만 수행하고,
  앱은 결과 JSON 만 받아 렌더링한다.
- **원문 기사 전문은 저장하지 않는다. 전체 번역도 하지 않는다.**
  RSS 메타데이터(제목/링크/발행일/출처/짧은 요약)만 수집하며,
  `sourceSummary` 도 300자로 잘라 검증용으로만 보관한다(앱 미표시).
  **AI 브리핑도 이 메타데이터만 입력으로 사용한다** — 원문 본문을
  가져오거나 전문 번역을 만들지 않는다.
- `aiBriefKo` 는 기본적으로 placeholder("AI 브리핑은 서버 요약 파이프라인
  연결 후 제공될 예정입니다.")다 — 앱 모델에서 필수 필드라 비워두면 항목이
  통째로 skip 되기 때문. `NEWS_AI_ENABLED=true` 일 때만 AI 브리핑을 생성한다.

## 실행 방법

```powershell
cd C:\Users\2001m\fmk-f1-calendar
npm run news-collector                       # AI 비활성 실행 (placeholder, git 무시됨)
npm run news-collector -- --out out.json     # 출력 경로 지정
npm run news-collector -- --stdout           # 파일 대신 표준출력
npm run news-collector:test                  # 단위 테스트 (네트워크/AI 호출 불필요)
```

AI 브리핑까지 생성하려면 (PowerShell):

```powershell
$env:NEWS_AI_ENABLED = "true"
$env:ANTHROPIC_API_KEY = "sk-ant-..."   # 없으면 호출 없이 fallback 문구 사용
npm run news-collector
```

## AI 브리핑 단계 (`news-ai-briefing.ts`)

`NEWS_AI_ENABLED=true` 일 때 한국어 제목(`titleKo`) + **정확히 3문장** 요약
(`aiBriefKo`: 무슨 일 / 왜 중요 / 볼 포인트) + 태그(`tags`, 최대 5개)를
생성한다. 응답은 구조화 출력(JSON schema)으로
`{titleKo, aiBriefKo, tags}` 형태를 고정한다.

| 환경변수 | 기본값 | 설명 |
|---|---|---|
| `NEWS_AI_ENABLED` | (비활성) | `true`/`1` 일 때만 AI 호출. 비활성이면 placeholder 유지 |
| `ANTHROPIC_API_KEY` | — | 없으면 AI 호출 없이 fallback 문구 사용 |
| `NEWS_AI_MODEL` | `claude-haiku-4-5` | 사용할 Claude 모델(가성비 기본값) |
| `NEWS_AI_INTERVAL_MINUTES` | `360` | 스케줄러의 AI 호출 허용 주기(RSS 주기와 분리) |
| `NEWS_AI_MAX_CALLS_PER_RUN` | `20` | 실행당 실제 API 호출 상한(캐시 hit 제외) |
| `NEWS_AI_DEBUG` | (비활성) | `true` 면 항목별 fallback 사유 로그 |

**hash 캐시**: 성공 결과는 `.news/news-ai-cache.json`(gitignore, 최근 800개)에
`{hash, titleKo, aiBriefKo, tags, generatedAt, model}` 로 저장되고, 같은
hash 는 다시 호출하지 않는다. 원문 전문/요약 원본은 캐시에 저장하지 않는다.
캐시 파일이 없거나 깨져도 빈 캐시로 시작한다(크래시 없음).

**프롬프트 규칙**(`NEWS_AI_PROMPT_VERSION` = `mobile-card-v2`): 모바일 카드
기준 — 제목 28자 이내 권장(하드 컷 60자, 자극·낚시 금지) / 정확히 3문장·
전체 120자 이내 권장, 문장당 35~45자(무슨 일→왜 중요→볼 포인트) /
F1 고유명사 한국어 표기표 포함(조지 러셀, 샤를 르클레르, 스파-프랑코샹 등) /
전체 번역 금지 / 제목·RSS 요약에 없는 사실 추가 금지 / 단정·과장 금지.
프롬프트를 바꾸면 버전 문자열도 올릴 것 — 캐시가 버전이 다른 옛 결과를
재사용하지 않는다(promptVersion 필드, 구버전 캐시 파일과 하위 호환).

**fallback 정책** — 다음 경우 해당 항목만 대체하고 전체 수집은 계속한다.
사유는 실행 통계 로그에 집계된다(ai_disabled / missing_api_key /
missing_title / missing_summary / short_summary / api_error / invalid_json /
empty_response / too_long_response / schema_error / interval_skip /
max_calls_skip). `aiBriefKo` fallback 문구:

> "해당 소식은 원문 제목과 출처를 기준으로 확인이 필요합니다. 자세한 내용은 원문 링크에서 확인해 주세요."

`titleKo` fallback 은 빈 문자열 — 앱이 제목 영역을 생략한다(영어 제목 미노출).

**진단 로그**: 시작 시 설정 요약(`[news-ai] config: ...`, key 는 존재 여부만),
실행마다 통계(`total/cacheHits/aiCalls/success/fallback + 사유별 카운트`).
API 오류는 모델명/status/에러 타입을 남긴다(key 값·기사 전문은 로그 금지).

## 전체 흐름 (수집 → API → 앱)

```
npm run news-collector          ┌ NEWS_AI_ENABLED=true 면 AI 브리핑 포함
        │                       ┘
        ▼
 .news/news.json  ──읽기──▶  GET /api/news?limit=20&lang=ko  ──▶  비아 포뮬러 앱
                             (app/api/news/route.ts)              (HttpNewsRepository)
```

1. `npm run news-collector` 가 `.news/news.json` 생성 (AI 활성 시 브리핑 포함)
2. Next.js 라우트 `/api/news` 가 그 파일을 읽어 계약 형태로 서빙
3. **Flutter 앱은 이 API 만 호출한다** — 직접 크롤링하지 않는다

### /api/news 동작

- `limit`: 기본 20, 최대 50 (초과·비정상 값은 각각 상한/기본값 처리)
- `lang`: 현재 `ko` 만 지원. 다른 값이 와도 ko 데이터를 그대로 반환
  (항목을 언어별로 만들지 않기 때문 — 계약 문서와 동일)
- 캐시: `Cache-Control: public, max-age=0, s-maxage=120,
  stale-while-revalidate=300` — CDN 2분 캐시라 소식 갱신이 크게 늦지 않는다
- **소스가 없거나 깨져도 500 없이 빈 `items` 로 200 응답**
  (앱은 빈 상태 카드를 표시). 배포 직후 수집 전 상태도 정상 흐름으로 처리
- 데이터 소스는 순서대로 시도: ① `NEWS_JSON_REMOTE_URL`(원격 JSON URL,
  프로덕션용 — 2.5초 타임아웃) → ② `NEWS_JSON_PATH` 또는 `.news/news.json`
  (로컬, 개발용) → ③ 빈 응답

> ⚠️ 배포 주의: 웹앱은 Vercel(서버리스)이라 `.news/` 로컬 파일이 배포에
> 존재하지 않는다. 실서비스는 `NEWS_JSON_REMOTE_URL` 로 원격 소스를
> 연결해야 한다 — 저장/주기 실행 계획은
> [news_deployment_plan.md](news_deployment_plan.md) 참고.

로컬 확인:

```powershell
npm run news-collector   # 데이터 생성
npm run dev              # http://localhost:3000/api/news?limit=20&lang=ko
```

## 수집 출처 (2026-07-08 확인)

| 출처 | feedUrl | 상태 |
|---|---|---|
| Motorsport.com | `https://www.motorsport.com/rss/f1/news/` | ✅ enabled |
| Autosport | `https://www.autosport.com/rss/f1/news/` | ✅ enabled |
| RaceFans | `https://www.racefans.net/feed/` | ✅ enabled (F1 외 카테고리 섞임, 가끔 429 rate limit) |
| The Race | `https://the-race.com/category/formula-1/feed/` | ✅ enabled (`/formula-1/feed/` 는 404) |
| GPToday | `https://www.gptoday.com/rss/` | ❌ disabled — 403(봇 차단 추정), TODO: 접근 가능한 URL 확인 |

출처는 스크립트 상단 `NEWS_SOURCES` 배열에서 관리한다. 한 출처가
실패(HTTP 오류/타임아웃)해도 그 출처만 건너뛰고 나머지는 계속 수집한다.

## 처리 규칙

1. RSS 2.0 `<item>` 에서 title/link/pubDate/description + 썸네일 URL 을 추출
   (의존성 없는 자체 파서, 깨진 항목은 그 항목만 skip). 썸네일은 출처가
   RSS 로 직접 제공한 `<enclosure type="image/*">`/`<media:content>`/
   `<media:thumbnail>` 만 사용 — 원문 페이지 크롤링 없음. 미제공 출처는
   `thumbnailUrl` 빈 값(앱이 생략)
2. 링크의 `utm_*` 추적 파라미터 제거(같은 기사가 다른 링크로 보이는 것 방지)
3. **중복 제거 2단계**:
   ① 정규화된 originalLink 기준(링크가 불안정하면 `sourceName+originalTitle` 해시)
   ② **유사 기사 묶기** — 발행 48시간 이내 기사끼리 제목(originalTitle+titleKo)
   /요약(sourceSummary+aiBriefKo) 토큰 겹침이 기준(0.7/0.65) 이상이면 같은
   뉴스로 판정(Motorsport.com↔Autosport 중복 대응). 대표 기사는
   한국어 브리핑 보유 → 요약 충실도 → 최신 → 출처 우선순위 순으로 고르고,
   묶인 출처는 `relatedSources` 로 보존(앱이 "외 1곳" 표시)
4. publishedAt **최신순 정렬** + **출처별 상한**(`NEWS_MAX_PER_SOURCE`, 기본 8
   — 한 출처의 독식 방지, 상한 탓에 20개를 못 채우면 백필) 을 적용해
   **20개**(`API_ITEM_LIMIT`, 앱 `kNewsDisplayLimit` 과 동일)만 출력.
   내부적으로는 출처당 50개까지 수집해 두어 향후 DB 저장으로 확장 가능
5. `id`/`hash` 는 링크의 SHA-1 에서 파생 — 실행 시점과 무관하게 안정적

## 출력 구조

[news_api_contract.md](news_api_contract.md)의 응답과 동일한 래퍼 형태:

```json
{
  "generatedAt": "2026-07-08T02:00:44.680Z",
  "items": [
    {
      "id": "news-c4e9d99cfe16",
      "sourceName": "Motorsport.com",
      "originalTitle": "...",
      "originalLink": "https://www.motorsport.com/f1/news/.../",
      "publishedAt": "2026-07-07T23:05:02.000Z",
      "fetchedAt": "2026-07-08T02:00:44.680Z",
      "sourceSummary": "... (300자 제한, 앱 미표시)",
      "aiBriefKo": "AI 브리핑은 서버 요약 파이프라인 연결 후 제공될 예정입니다.",
      "tags": [],
      "hash": "sha1:c4e9d99c..."
    }
  ]
}
```

실제 출력이 앱 파서(`parseNewsJson`)로 20건 그대로 파싱되는 것을
교차 검증했다(2026-07-08).

## 남은 단계 (TODO)

- ~~AI 요약 파이프라인~~ → `news-ai-briefing.ts` 완료(기본 비활성,
  `NEWS_AI_ENABLED=true` + API key 로 활성, hash 캐시·호출 상한·주기 분리 포함)
- ~~`/api/news` HTTP 엔드포인트~~ → `app/api/news/route.ts` 완료
  (원격 소스 `NEWS_JSON_REMOTE_URL` 지원 포함).
  남은 것: 뉴스 수집 주기 실행 + 원격 서빙 —
  [news_deployment_plan.md](news_deployment_plan.md) 의 체크리스트 참고
- ~~앱 `NewsScreen` 기본 저장소를 `HttpNewsRepository` 로 교체~~ → 완료
  (origin: `lib/services/news_repository.dart` 의 `kNewsApiBaseUrl`)
