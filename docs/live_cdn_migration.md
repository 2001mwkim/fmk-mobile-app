# 라이브 엔드포인트 이전 — Vercel → Cloudflare(무료) + Railway

## 왜

릴리스 빌드의 라이브 URL 기본값은 Railway 직결이 아니라 **Vercel `/api/live`** 다
(`lib/services/live_session_service.dart` 의 `kLiveJsonUrl`). Vercel 무료 플랜은
엣지 요청 월 100만 건이 상한이고 **캐시 HIT 도 1건으로 계산**한다. 원본은 5초에 한 번만
일하는데 요금만 사용자 수에 비례해 오르는 구조다.

Cloudflare 무료는 요청 수를 세지 않고 서울 PoP 가 있어 지연도 지금 수준으로 유지된다.
앞단에 짧은 캐시를 두면 **Railway 가 실제로 처리하는 요청은 사용자 수와 무관하게
분당 12회로 고정**된다.

측정값(2026-08-24, 서울에서):

| | 응답 | 크기 | 캐시 |
|---|---|---|---|
| Vercel `/api/live` | 0.06초 | 4.4 KB (gzip) | HIT/STALE 동작 |
| Railway `live.json` 직결 | 0.55초 | 29.5 KB (압축 없음) | 없음 |

**Railway 앞에 캐시/압축 없이 직결하면 대역폭이 6.7배로 뛴다.** 아래 1번을 반드시 먼저.

## 1. collector: 압축 + 캐시 헤더 (자매 저장소 `fmk-f1-calendar`)

`scripts/signalr-live-collector.ts` 의 HTTP 서빙부. Express 라면:

```ts
import compression from 'compression'
app.use(compression())

app.get('/live.json', (req, res) => {
  // 앞단(Cloudflare)이 3초간 캐시하고, 만료 후 30초까지는 낡은 값을 주면서
  // 뒤에서 갱신한다 → 원본은 사용자 수와 무관하게 분당 12회만 일한다.
  res.set('Cache-Control', 'public, s-maxage=3, stale-while-revalidate=30')
  res.json(latestSnapshot)
})
```

`http.createServer` 를 직접 쓰고 있다면 `zlib.gzipSync` + 같은 헤더로 대체.

확인:

```bash
curl -sI -H "Accept-Encoding: gzip" https://live-production-c03d.up.railway.app/live.json | grep -i "content-encoding\|cache-control"
```

`content-encoding: gzip` 과 `cache-control: public, s-maxage=3, ...` 이 나와야 한다.

## 2. Cloudflare

1. Cloudflare 계정 생성 → `formulamagazine.kr` 추가 → 안내대로 **네임서버를 Cloudflare 로 변경**
   (도메인 등록기관에서 설정. 반영까지 최대 24시간)
2. DNS 에 `live` 레코드 추가 — CNAME → `live-production-c03d.up.railway.app`,
   **프록시 켬(주황색 구름)**. 꺼져 있으면 캐시도 압축도 안 걸린다.
3. Rules → **Cache Rules** 새 규칙:
   - 조건: `Hostname equals live.formulamagazine.kr`
   - 동작: **Eligible for cache**
   - Edge TTL: **Use cache-control header from origin**
   - Browser TTL: Respect origin
   - JSON 응답은 기본적으로 캐시되지 않으므로 **이 규칙이 없으면 전부 Railway 로 통과한다.**

확인:

```bash
curl -sI https://live.formulamagazine.kr/live.json | grep -i "cf-cache-status\|content-encoding"
```

두 번째 호출부터 `cf-cache-status: HIT` 이 나와야 성공. `DYNAMIC` 이면 3번 규칙이 안 걸린 것.

## 3. 앱

코드 변경은 이미 끝나 있다. 빌드 플래그만 바꾸면 된다.

```powershell
flutter build appbundle --release `
  --dart-define=LIVE_JSON_URL=https://live.formulamagazine.kr/live.json `
  --dart-define=LIVE_FAST_POLL=true
```

- `LIVE_JSON_URL` — 라이브 폴링 대상. Vercel 을 더 이상 타지 않는다.
- `LIVE_FAST_POLL` — 레이스/스프린트 중 폴링을 20초 → **10초**로 당긴다
  (`LiveSessionController.fastPollDuringRace`). 연습/퀄리는 켜도 20초 유지.
  **1·2번이 끝나기 전에는 켜지 말 것** — 요청이 두 배가 된다.

Android Now Bar 서비스(`LiveActivityService.kt`)는 브리지가 저장한 `liveJsonUrl`
키를 그대로 쓰므로 자동으로 새 주소를 따라간다.

## 되돌리기

`--dart-define` 을 빼면 릴리스 기본값(Vercel)으로 돌아간다. 코드 수정 불필요.

## 이전 후 확인할 것

- Vercel 대시보드 엣지 요청 증가 속도가 꺾이는지 (라이브가 빠지면 대부분 사라진다)
- Railway 사용량 — 캐시가 걸렸다면 사용자 수와 무관하게 거의 평평해야 한다.
  계속 오르면 `cf-cache-status` 가 HIT 이 아닌 것이니 2-3 번을 다시 볼 것
