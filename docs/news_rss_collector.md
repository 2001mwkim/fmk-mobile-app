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

`NEWS_AI_ENABLED=true` 일 때 최종 출력(최대 20개)에 대해서만 Claude API 로
2~3줄 한국어 브리핑(`aiBriefKo`)과 태그(`tags`)를 생성한다.

| 환경변수 | 기본값 | 설명 |
|---|---|---|
| `NEWS_AI_ENABLED` | (비활성) | `true`/`1` 일 때만 AI 호출. 비활성이면 placeholder 유지 |
| `ANTHROPIC_API_KEY` | — | 없으면 AI 호출 없이 fallback 문구 사용 |
| `NEWS_AI_MODEL` | `claude-opus-4-8` | 사용할 Claude 모델 |

호출 상한은 코드 상수 `NEWS_AI_MAX_ITEMS_DEFAULT`(20 = 앱 노출 한도)로,
비용/속도 보호를 위해 실행당 최대 20개만 요약한다.

**프롬프트 규칙**: 한국어 / 2~3문장 / 전체 번역 금지 / 제목·RSS 요약에 없는
사실 추가 금지 / 불확실한 내용 단정 금지 / 과장 금지 / 한국 F1 팬 기준
중요성 한 구절. 응답은 구조화 출력(JSON schema)으로 형태를 고정한다.

**fallback 정책** — 다음 경우 해당 항목만 아래 문구로 대체한다(전체 실패 없음):
sourceSummary 없음·40자 미만 / originalTitle 없음 / API key 없음 /
호출 실패 / 응답 JSON 파싱 실패 / 브리핑이 비었거나 350자 초과.

> "해당 소식은 원문 제목과 출처를 기준으로 확인이 필요합니다. 자세한 내용은 원문 링크에서 확인해 주세요."

TODO: `hash` 기반 요약 캐시(같은 기사 재요약 방지) — DB 도입 시 구현.

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
- **파일 없음/깨진 JSON 이어도 500 없이 빈 `items` 로 200 응답**
  (앱은 빈 상태 카드를 표시). 배포 직후 수집 전 상태도 정상 흐름으로 처리
- 데이터 파일 경로는 `NEWS_JSON_PATH` 환경변수로 교체 가능

> ⚠️ 배포 주의: `.news/` 는 git 무시라서 새 배포에는 파일이 없다.
> 실서비스 전에 서버에서 collector 를 주기 실행(cron)하거나 빌드/시작 시
> 생성하는 단계가 필요하다 — 그 전까지 `/api/news` 는 빈 목록을 돌려준다.

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

1. RSS 2.0 `<item>` 에서 title/link/pubDate/description 만 추출
   (의존성 없는 자체 파서, 깨진 항목은 그 항목만 skip)
2. 링크의 `utm_*` 추적 파라미터 제거(같은 기사가 다른 링크로 보이는 것 방지)
3. **중복 제거**: 정규화된 originalLink 기준, 링크가 불안정하면
   `sourceName + originalTitle` 해시 기준
4. publishedAt **최신순 정렬** 후 **20개**(`API_ITEM_LIMIT`, 앱
   `kNewsDisplayLimit` 과 동일)만 출력. 내부적으로는 출처당 50개까지
   수집해 두어 향후 DB 저장으로 확장 가능
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

- ~~AI 요약 파이프라인~~ → `news-ai-briefing.ts` 초안 완료(기본 비활성,
  `NEWS_AI_ENABLED=true` + API key 로 활성). 남은 것: `hash` 기반 요약 캐시
- ~~`/api/news` HTTP 엔드포인트~~ → `app/api/news/route.ts` 완료.
  남은 것: 서버에서 collector 주기 실행(cron 등)으로 `.news/news.json` 갱신
- 서빙 시작 시 앱 `NewsScreen` 기본 저장소를 `HttpNewsRepository` 로 교체
