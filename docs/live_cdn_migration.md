# 라이브 엔드포인트 — Cloudflare + Railway

**상태: 이전 완료 (2026-08-24).** 앱 릴리스 빌드만 남았다(아래 "남은 일").

```
앱 → live.formulamagazine.kr → Cloudflare(엣지 캐시 5초) → Railway collector
```

## 왜 옮겼나

릴리스 빌드의 라이브 URL 기본값은 Railway 직결이 아니라 **Vercel `/api/live`** 였다
(`lib/services/live_session_service.dart` 의 `kLiveJsonUrl`). Vercel 무료 플랜은 엣지
요청 월 100만 건이 상한이고 **캐시 HIT 도 1건으로 계산**한다. 원본은 5초에 한 번만
일하는데 요금만 사용자 수에 비례해 올랐다. 설치 5,000 규모에서 레이스 주말 하나가
약 42만 건이라 월 100만을 넘길 상황이었다.

Cloudflare 무료는 요청 수를 세지 않고 서울 PoP 가 있어 지연도 유지된다. 앞단 5초
캐시 덕에 **Railway 가 실제로 처리하는 요청은 사용자 수와 무관하게 고정**된다.

이전 전후 실측:

| | 응답 | 크기 | 캐시 |
|---|---|---|---|
| Vercel `/api/live` | 0.06초 | 4.4 KB | HIT |
| Railway 직결 | 0.55초 | 29.5 KB | 없음 |
| **Cloudflare + Railway (현재)** | **0.15초** | **4.1 KB** | **HIT** |

## 확정된 구성 — 건드리면 안 되는 것

`formulamagazine.kr` 네임서버는 비아웹 → **Cloudflare**(`sofia`/`kevin`.ns.cloudflare.com).
이 도메인에는 **다음(Daum) 메일이 붙어 있다.** DNS 를 손볼 일이 생기면 아래를 보존할 것.

| 종류 | 이름 | 값 | 프록시 |
|---|---|---|---|
| A | @ | 216.198.79.1 (Vercel) | **회색 · DNS only** |
| CNAME | www | 3be179c6efad8c83.vercel-dns-017.com | **회색 · DNS only** |
| MX | @ | 10 aspmx.daum.net | (해당 없음) |
| MX | @ | 20 alt.aspmx.daum.net | (해당 없음) |
| CNAME | live | d9yojixx.up.railway.app | **주황 · Proxied** |

**주황 구름은 `live` 하나뿐이다.** 웹사이트 레코드를 프록시로 켜면 Vercel 과 충돌하고,
MX 를 빠뜨리면 메일이 끊긴다.

SSL/TLS 모드는 **Full (strict)**. Flexible 로 두면 무한 리다이렉트가 난다.

### Cache Rule

Caching → Cache Rules, hostname = `live.formulamagazine.kr`

- Cache eligibility: **Eligible for cache**
- Edge TTL: **Use cache-control header if present, bypass cache if not**
  - "bypass if not" 이어야 한다. 헤더가 사라졌을 때 Cloudflare 기본 TTL 로 캐시하면
    라이브 순위가 몇 시간 굳는다. 느려지는 편이 틀린 데이터보다 낫다.
- Browser TTL: **Respect origin TTL**
  - 기본값이 4시간이라 그대로 두면 `max-age=0` 을 `max-age=14400` 으로 덮어쓴다.
    iOS 위젯·워치는 `URLSession` 이 이 헤더를 존중하므로 4시간 지난 라이브를 그린다.

collector 는 `Cache-Control: public, max-age=0, s-maxage=5, stale-while-revalidate=20`
을 **이미 보내고 있다.** 손댈 것 없다.

## 점검 방법

```powershell
# collector 가 HEAD 에 404 를 주므로 curl -I 는 쓰지 말 것
curl.exe -s -D - -o NUL https://live.formulamagazine.kr/live.json
```

정상이면 `cf-cache-status: HIT`(두 번째 호출부터), `content-encoding: gzip`,
`cache-control: ... max-age=0 ...`. `DYNAMIC` 이면 Cache Rule 이 안 걸린 것,
`max-age=14400` 이면 Browser TTL 이 원본을 덮어쓰는 것.

## 남은 일

앱은 아직 릴리스를 안 올려서 **기존 사용자는 Vercel 을 계속 쓴다.** 스토어에 새 버전이
올라가고 사용자들이 업데이트를 받아야 실제로 빠진다(며칠~2주). 전원 업데이트되면 앱이
쓰는 Vercel 요청이 월 89만 → 3~5만 건으로 떨어진다.

URL(`kLiveJsonUrl`)과 10초 폴링(`kLiveFastPollDuringRace`) **둘 다 기본값이라 플래그가
필요 없다.** 그냥 빌드하면 된다.

```powershell
flutter build appbundle --release
```

- 라이브 URL — `live.formulamagazine.kr` (d799cae 에서 기본값 전환)
- 레이스/스프린트 중 폴링 **10초**, 연습·퀄리는 20초 유지
- 되돌릴 때만 명시적으로: `--dart-define=LIVE_FAST_POLL=false`

두 값 모두 기본값을 옮긴 이유는 같다 — dart-define 을 깜빡한 빌드가 조용히 예전
동작으로 돌아가면 한도를 터뜨리거나 기능이 빠진 채 배포된다.

Android Now Bar(`LiveActivityService.kt`)는 브리지가 저장한 `liveJsonUrl` 키를 쓰므로
자동으로 새 주소를 따라간다.

## 라이브 센터 영상 지연

라이브 센터는 `live.json?delay=N`으로 0~120초의 영상 동기화 지연을 요청한다.
collector는 최근 5분의 전체 스냅샷을 1초 단위 메모리 링 버퍼에 보관하고,
요청 재생 시각보다 새롭지 않은 가장 가까운 스냅샷을 반환한다. 응답의
`playback.capturedAt`은 시간제 세션 카운트다운 보정에 사용한다.

Cloudflare와 Vercel은 쿼리 문자열별로 캐시가 분리되어야 한다. 구버전 collector가
쿼리를 무시해 최신 데이터를 노출하지 않도록 앱도 playback 메타데이터를 검증하므로,
배포 순서는 **collector → 앱**을 지킨다. 홈·위젯·Live Activity는 쿼리 없는 기존
실시간 endpoint를 계속 사용한다.

## 선택 사항

**collector gzip** — Cloudflare 가 사용자에게 보낼 때 자동 압축하므로 급하지 않다.
넣으면 Cloudflare↔Railway 구간(월 15~45GB → 2~7GB)만 줄어 **월 2천원 수준** 차이다.
같은 김에 HEAD 404 도 고치면 점검이 편해진다.

## 되돌리기

앱은 `--dart-define` 을 빼면 릴리스 기본값(Vercel)으로 돌아간다. 코드 수정 불필요.
DNS 전체를 되돌리려면 비아웹에서 네임서버를 `dns3/dns4.viaweb.co.kr` 로 되돌린다.

## 지켜볼 것

- **Vercel** — 릴리스 확산에 따라 엣지 요청이 줄어야 한다
- **Railway** — 캐시가 걸렸다면 사용자 수와 무관하게 거의 평평해야 한다. 계속 오르면
  `cf-cache-status` 를 다시 확인할 것
- **90일쯤 뒤** — Railway 인증서 갱신이 실패하면 `live` 를 잠깐 회색으로 바꿨다가
  갱신 후 다시 주황으로 켠다
