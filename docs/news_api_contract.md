# 소식(News) API 계약 v1

비아 포뮬러 앱 소식 탭이 사용할 서버 API 스펙. 서버 구현 전에 앱/서버가
합의할 계약을 먼저 고정해 둔다. 앱 쪽 파싱 구현은
`lib/models/news_item.dart` (`NewsItem.fromJson`)와
`lib/services/news_repository.dart` (`HttpNewsRepository`)에 있다.

## 목적과 정책 (중요)

- 서버가 해외 F1 뉴스를 수집·요약하고, 앱은 **정리된 JSON만 표시**한다.
  앱은 외부 뉴스 사이트를 직접 크롤링하지 않는다.
- 앱은 **원문 기사 전문을 저장하거나 전체 번역해서 보여주지 않는다.**
  2~3줄 한국어 AI 브리핑(`aiBriefKo`)과 원문 링크(`originalLink`)만
  제공하며, 출처(`sourceName`)를 항상 명시한다.
- 앱은 **최신 20개만 요청·노출**한다(`limit=20`,
  앱 상수 `kNewsDisplayLimit`).

## 요청

```
GET /api/news?limit=20&lang=ko
```

| 파라미터 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `limit` | int | 20 | 최신순으로 돌려줄 항목 수. 앱은 항상 20을 보낸다 |
| `lang` | string | `ko` | 브리핑 언어. 현재 `ko`만 사용 |

인증 없음(공개 데이터). 응답은 `Cache-Control` 로 짧은 캐시(예: 60s)를
허용해도 된다.

## 응답 (200, application/json)

```json
{
  "generatedAt": "2026-07-07T03:20:00.000Z",
  "items": [
    {
      "id": "news-20260707-001",
      "sourceName": "Motorsport.com",
      "originalTitle": "Leclerc holds off Russell in Silverstone thriller",
      "originalLink": "https://www.motorsport.com/f1/news/example-article",
      "publishedAt": "2026-07-07T01:10:00.000Z",
      "fetchedAt": "2026-07-07T01:20:00.000Z",
      "sourceSummary": "Charles Leclerc won the British GP after ...",
      "aiBriefKo": "르클레르가 실버스톤에서 러셀의 막판 추격을 0.4초 차로 막아내며 시즌 3승째를 거뒀습니다. 페라리는 컨스트럭터 선두와의 격차를 12점으로 좁혔습니다.",
      "tags": ["르클레르", "페라리", "영국 GP"],
      "hash": "sha1:9f2c..."
    }
  ]
}
```

`items` 는 **publishedAt 내림차순(최신순)** 정렬을 권장한다
(앱도 방어적으로 재정렬한다).

## 필드 설명

| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `id` | string | ✅ | 항목 고유 ID |
| `sourceName` | string | ✅ | 출처 매체명. 카드에 항상 노출(출처 명시 정책) |
| `originalTitle` | string | ✅ | 원문 제목(원어) |
| `originalLink` | string | ✅ | 원문 기사 URL. '원문 보기' 링크 |
| `publishedAt` | string(ISO 8601) | ✅ | 원문 발행 시각(UTC 권장) |
| `fetchedAt` | string(ISO 8601) | ⬜ | 서버 수집 시각. 없으면 앱이 publishedAt 으로 대체 |
| `sourceSummary` | string | ⬜ | RSS 등 출처 제공 요약(원어). 앱 미표시, 디버그/검증용 |
| `aiBriefKo` | string | ✅ | 2~3줄 한국어 AI 브리핑. 앱 카드 본문 |
| `tags` | string[] | ⬜ | 드라이버/팀/그랑프리 태그(한국어). 없으면 빈 배열 |
| `hash` | string | ⬜ | 중복 수집 방지용 콘텐츠 해시. 없으면 앱이 id 로 대체 |

## 앱 쪽 파싱 규칙 (서버 참고사항)

- 필수 필드가 없거나 형식이 깨진 항목은 **그 항목만 건너뛴다**
  (전체 실패 아님). 서버 배포 중 일부 항목이 깨져도 나머지는 표시된다.
- 네트워크 오류·타임아웃(8초)·비정상 JSON 이면 앱은 빈 목록으로 처리하고
  화면에 "표시할 소식이 없습니다"를 보여준다(크래시 없음).
- 하위 호환: 루트가 `{ "items": [...] }` 래퍼 대신 배열이어도 파싱한다.
  단, 서버는 확장성을 위해 래퍼 형태를 표준으로 한다.

## 버저닝

응답에 필드를 **추가**하는 변경은 자유(앱은 모르는 필드를 무시).
필수 필드의 의미/타입 변경은 파괴적 변경이므로 경로 버전(`/api/v2/news`)으로
분리한다.
