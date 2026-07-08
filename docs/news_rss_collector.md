# 소식 RSS 수집기 (초안)

비아 포뮬러 앱 소식 탭에 내려줄 `news.json` 을 만드는 서버/스크립트 계층
수집기. **앱 저장소가 아니라 자매 저장소(fmk-f1-calendar)에 있다** —
live.json collector 와 같은 계층이다.

- 스크립트: `C:\Users\2001m\fmk-f1-calendar\scripts\news-rss-collector.ts`
- 테스트: 같은 폴더의 `news-rss-collector.test.ts`
- 출력 계약: 이 저장소의 [news_api_contract.md](news_api_contract.md)와 동일
  (앱 모델 `lib/models/news_item.dart` 와 **수동 동기화** — 필드 변경 시
  수집기·계약 문서·앱 모델을 함께 고칠 것)

## 목적과 정책 (중요)

- **앱은 크롤링하지 않는다.** RSS 수집은 이 스크립트에서만 수행하고,
  앱은 결과 JSON 만 받아 렌더링한다.
- **원문 기사 전문은 저장하지 않는다. 전체 번역도 하지 않는다.**
  RSS 메타데이터(제목/링크/발행일/출처/짧은 요약)만 수집하며,
  `sourceSummary` 도 300자로 잘라 검증용으로만 보관한다(앱 미표시).
- `aiBriefKo` 는 아직 생성하지 않는다. AI 요약 파이프라인 연결 전까지
  placeholder("AI 브리핑은 서버 요약 파이프라인 연결 후 제공될 예정입니다.")를
  넣는다 — 앱 모델에서 필수 필드라 비워두면 항목이 통째로 skip 되기 때문.

## 실행 방법

```powershell
cd C:\Users\2001m\fmk-f1-calendar
npm run news-collector                       # .news/news.json 생성 (git 무시됨)
npm run news-collector -- --out out.json     # 출력 경로 지정
npm run news-collector -- --stdout           # 파일 대신 표준출력
npm run news-collector:test                  # 단위 테스트 (네트워크 불필요)
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

- AI 요약 파이프라인: `sourceSummary`/원문 제목 기반 2~3줄 한국어 브리핑
  생성 → `aiBriefKo` 채우기, 태그(`tags`) 생성
- `/api/news` HTTP 엔드포인트로 서빙(현재는 파일 출력만)
- 서빙 시작 시 앱 `NewsScreen` 기본 저장소를 `HttpNewsRepository` 로 교체
