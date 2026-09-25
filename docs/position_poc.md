# Position.z feasibility POC (2026-09)

> ## ⛔ 실측 결과 (2026-09-25, 아제르바이잔 GP Practice 3 라이브 중)
>
> **현재 쓰는 엔드포인트에서는 Position.z 를 받을 수 없다.** 디코더 문제가
> 아니라 데이터가 아예 오지 않는다. 아래는 추측이 아니라 라이브 세션에서
> 직접 측정한 결과다.
>
> | 확인 항목 | 결과 |
> |---|---|
> | Subscribe 에 `Position.z` 포함 | 보냄 (13개 토픽) |
> | Subscribe 응답에 Position 키 | **없음** (11개만 반환) |
> | 45~60초간 Position feed 델타 | **0건** (같은 시간 TimingData 는 97~109건) |
> | 토픽명 변형 6종 시도 | `Position`, `Position.z`, `CarData`, `CarData.z`, `PositionData`, `Positions` **전부 무시** |
> | feed 외 다른 target 으로 수신 | 없음 (target 분포: feed 97, ping 3, completion 1) |
> | 구형 `/signalr` 엔드포인트 | **HTTP 401** (헤더 조합 5종 모두 실패) |
>
> `livetiming.formula1.com/signalrcore` 는 **모르는 토픽을 오류 없이 조용히
> 무시**한다. 그래서 구독은 성공한 것처럼 보이지만 해당 토픽은 응답 키에서
> 빠지고 델타도 오지 않는다. 공개 클라이언트들이 Position.z 를 받던 구형
> `/signalr`(ASP.NET SignalR 1.x, Streaming 허브)은 지금 401 로 막혀 있다.
>
> **다음 단계는 디코더 수정이 아니라 데이터 접근 경로 확보다.** 후보:
> 구형 엔드포인트의 인증 요건 확인, F1 공식 라이선스 피드, 또는 Position 없이
> TimingData 기반 트랙맵(섹터/구간 단위 근사).
>
> 아래 문서의 나머지 내용(디코더·엔드포인트·앱 화면·계측)은 **데이터가 확보되면
> 그대로 쓸 수 있는 상태**로 남겨 둔다. 합성 피더(`POSITION_MOCK=1`)로 배관
> 전체가 동작하는 것은 확인했다.

실시간 트랙맵을 **서버 비용 최소로** 제공할 수 있는지 판단하기 위한 실험이다.
프로덕션 기능이 아니며, 실험이 끝나면 통째로 제거하거나 정식 설계로 대체한다.

답하려는 질문: **Position.z 를 어떤 주기로, 어떤 구조로 전달하는 것이 가장
효율적인가?**

---

## 1. 켜고 끄기

기본값은 **꺼짐**이다. 꺼져 있으면 구독 목록에 `Position.z` 가 아예 들어가지
않아 수신·디코딩·메모리 사용이 0 이고, collector 동작은 기존과 동일하다.

| 환경변수 | 기본값 | 역할 |
|---|---|---|
| `POSITION_EXPERIMENT` | (없음=꺼짐) | `1` 이면 Position.z 구독 + `/debug/position` 제공 |
| `POSITION_MOCK` | (없음=꺼짐) | `1` 이면 합성 좌표 피더 가동(세션 전 배관 검증용) |
| `POSITION_MOCK_INTERVAL_MS` | `250` | 합성 피더 주기 |

로컬 검증:

```sh
# 세션 없이 배관 전체 검증(합성 데이터)
POSITION_EXPERIMENT=1 POSITION_MOCK=1 LIVE_MOCK_MODE=live npm run live-collector:dev

# 실제 세션 수집
POSITION_EXPERIMENT=1 npm run live-collector:dev
```

Railway 는 환경변수에 `POSITION_EXPERIMENT=1` 만 추가하면 된다.
**세션이 끝나면 지워서 원상복구한다.**

---

## 2. 디코딩 방식

`.z` 는 압축 페이로드를 뜻하지만, 이 저장소에는 압축 토픽을 다뤄 본 코드가
없었다. 그래서 **형식을 하나로 가정하지 않고** 순서대로 시도하고 *성공한 전략을
기록*한다. 실제 형식은 세션에서 `decodeStrategy` 값으로 확정된다.

1. `plain-object` — 이미 객체로 온 경우
2. `base64+inflateRaw` — base64 + raw deflate (`.z` 로 가장 유력)
3. `base64+inflate` — zlib 헤더 포함
4. `base64+gunzip` — gzip
5. `json-string` — 비압축 JSON 문자열

정규화 결과:

```json
{ "racingNumber": "1", "x": -7903, "y": -807, "z": 37, "status": "OnTrack" }
```

프레임 형태도 두 가지를 받는다: `{Position:[{Timestamp, Entries:{번호:{X,Y,Z}}}]}`
와 `Entries` 래퍼 없이 번호 키가 바로 오는 형태. 둘 다 아니면 실패로 집계하고
**throw 하지 않는다**.

---

## 3. 테스트 endpoint

```
GET /debug/position?mode=raw|5hz|2hz|1hz[&metrics=0]
```

- `Cache-Control: no-store` — Cloudflare 캐시에 얹히지 않는다
- `X-Position-Bytes` 헤더로 본문 크기 노출
- `metrics=0` 은 프레임만 반환 → **실제 전송 구조의 페이로드 크기 측정용**
- 응답의 `mock: true` 는 합성 데이터라는 뜻이다. 실제 세션 측정값과 섞지 말 것

응답에 포함되는 debug 메타: `sourceTimestamp`, `collectorReceivedAt`,
`servedAt`, `driverCount`, `rawUpdatesPerSecond`, `lastUpdateAgeMs`,
`decodeStrategy`, `buildMs`.

---

### Cloudflare 캐시 — 확인 결과

`live.formulamagazine.kr` 의 Cache Rule 은 **호스트 전체**에 걸려 있어
`/debug/position` 도 같은 규칙을 탄다([live_cdn_migration.md](live_cdn_migration.md)).
Edge TTL 이 `Use cache-control header if present, bypass cache if not` 이므로
origin 이 보내는 `no-store` 가 그대로 존중된다.

2026-09-25 실측(같은 호스트의 기존 no-store 경로로 확인):

| 경로 | origin 헤더 | cf-cache-status |
|---|---|---|
| `/healthz` | `no-store` | **BYPASS** (2회 연속) |
| `/live.json` | `s-maxage=5` | HIT (Age 있음) |

즉 **추가 Cloudflare 설정 없이도 `/debug/position` 은 캐시되지 않는다.**
응답에는 `Cache-Control` 외에 `CDN-Cache-Control` / `Cloudflare-CDN-Cache-Control`
도 `no-store` 로 함께 보낸다(Edge TTL 설정이 바뀌거나 다른 CDN 이 끼는 경우 대비).

**세션 중 반드시 확인할 것** — 엣지가 한 프레임이라도 캐시하면 주기·지연 측정이
통째로 틀어진다:

```sh
curl -s -D - -o /dev/null "https://live.formulamagazine.kr/debug/position?mode=raw" \
  | grep -i "cf-cache-status"
# 기대: BYPASS  (HIT/EXPIRED 가 나오면 즉시 Railway 직결로 전환)
```

`HIT` 가 나오면 아래 Cache Rule 을 추가한다(평소엔 불필요):

- Caching → Cache Rules → **Create rule**, 기존 규칙보다 **우선순위 위로**
- 이름: `debug bypass`
- 식: `http.host eq "live.formulamagazine.kr" and starts_with(http.request.uri.path, "/debug/")`
- 설정: **Bypass cache**

캐시 영향을 아예 배제하고 싶으면 앱을 Railway 직결로 붙여도 된다(측정 전용,
단일 사용자라 origin 부하는 무시할 수준이다):

```
https://live-production-c03d.up.railway.app/debug/position
```

다만 지연이 0.15초 → 0.55초로 늘어 **체감 부드러움 비교에는 불리**하다.
주기·payload 측정은 직결, 체감 비교는 Cloudflare 쪽을 권한다.

## 4. 앱 디버그 화면

설정 › **Position 실험 (디버그)** › `Position 트랙맵 열기`
(`kDebugMode` 가드 — 릴리스 빌드에는 존재하지 않는다)

실기기에서 볼 때는 collector 주소를 주입한다:

```sh
flutter run --dart-define=POSITION_DEBUG_URL=http://<PC-LAN-IP>:8787/debug/position
```

화면 기능: RAW/5Hz/2Hz/1Hz 전환, 보간 ON/OFF, 궤적 ON/OFF, 측정 초기화.
좌표는 고정 변환 없이 **관측 범위로 자동 맞춤**한다 — 차량이 그리는 궤적이
실제 서킷 모양이 되는지가 곧 좌표계 검증이다.

보간은 마지막 두 프레임 사이를 60fps 로 선형 보간하며 **외삽하지 않는다**
(`t` 가 1 에서 멈춤 → 데이터가 늦으면 마지막 위치 유지).

---

## 5. 오늘 세션 진행 순서

세션 시작 **전**:

1. Railway 에 `POSITION_EXPERIMENT=1` 추가 → 재배포 → 로그에서 `[POSITION] 실험 활성화` 확인
2. `curl -s https://live.formulamagazine.kr/live.json | head -c 200` — **기존 라이브 정상 확인**
3. 앱(VIA Live Center) 정상 동작 확인
4. Railway Metrics 에서 **Position 추가 전 baseline** 기록: CPU / Memory / Network Egress

세션 **중**:

5. `curl -s "https://live.formulamagazine.kr/debug/position?mode=raw" | head -c 400`
   → `decodeStrategy`, `driverCount` 확인 (**여기서 실제 형식이 확정된다**)
6. collector 로그에서 `[POSITION METRICS]` 1분 단위 통계 확인
7. `[POSITION] raw sample` 로그로 원본 형식 육안 확인
8. 앱 디버그 화면에서 RAW → 5Hz → 2Hz → 1Hz 순으로 체감 비교
9. 각 모드에서 보간 OFF → ON 비교
10. 모드별 payload 크기 기록 (`metrics=0` 기준)
11. Railway Metrics 재확인 → baseline 과 비교

세션 **후**:

12. `/live.json` 과 Live Center 정상 동작 재확인
13. collector 재시작 없이 계속 떠 있었는지 로그로 확인(reconnect 로그 급증 없어야 함)
14. Railway 에서 `POSITION_EXPERIMENT` 제거 → 재배포(원상복구)

---

## 6. 결과 기록표

### A. Position.z 실측

| 항목 | 값 |
|---|---|
| 첫 수신 시각 | |
| decodeStrategy | |
| 평균 frequency (msg/s) | |
| 최대 frequency (peak/s) | |
| raw payload 평균 (bytes) | |
| 정규화 payload 평균 (bytes) | |
| driver count | |
| decode errors | |
| malformed | |
| decode 평균 시간 (ms) | |

### B. 트랙맵 체감

| 모드 | 부드러움(보간 OFF) | 부드러움(보간 ON) | 비고 |
|---|---|---|---|
| RAW | | | |
| 5Hz | | | |
| 2Hz | | | |
| 1Hz | | | |

### C. Railway

| 지표 | Position 추가 전 | 추가 후 |
|---|---|---|
| CPU | | |
| Memory | | |
| Network Egress | | |

### D. 예상 트래픽

`/debug/position` 응답의 `traffic` 필드가 계산해 준다. 두 구조를 **반드시
구분**해서 본다:

- `originBytesPerHourDirect` — Railway 가 사용자에게 직접 전송(사용자 수에 비례)
- `originBytesPerHourViaRelay` — Railway → 릴레이 1벌만(사용자 수와 무관)
- `edgeBytesPerHourViaRelay` — 팬아웃을 엣지가 부담

| 사용자 | 1Hz 직결 | 2Hz 직결 | 5Hz 직결 | 릴레이(모든 주기) |
|---|---|---|---|---|
| 100 | | | | |
| 500 | | | | |
| 1,000 | | | | |
| 5,000 | | | | |

### E. 아키텍처 후보

| 후보 | 비용 | latency | 개발 난이도 | 확장성 |
|---|---|---|---|---|
| 1. Timing=캐시 폴링 / Position=경량 폴링 | | | | |
| 2. Timing=캐시 폴링 / Position=엣지 실시간 릴레이 | | | | |
| 3. Timing+Position 전면 실시간 | | | | |

판단 기준은 속도만이 아니다. **Railway 가 사용자 수만큼 실시간 연결을 유지하는
구조는 성급히 도입하지 않는다** — 현재 Cloudflare 캐시가 주는 origin 보호
(사용자 수와 무관한 고정 origin 부하)를 잃기 때문이다.

---

## 7. 아직 검증되지 않은 것

- **실제 F1 Position.z 페이로드 형식** — 디코더는 5가지 전략을 자동 판별하도록
  만들었지만, 실제로 어느 것이 맞는지는 세션에서만 확인된다
- **실제 업데이트 주기** — 추정값이 아니라 세션 실측이 필요하다
- **좌표계 방향/스케일** — 화면은 Y 축을 뒤집어 그리지만, 실제 방향은 궤적
  모양으로 확인해야 한다
- **서킷 SVG 와 position 좌표의 정합** — 이번 POC 는 좌표 자동 맞춤만 하고
  SVG 정렬은 하지 않는다
- **실기기에서의 체감 차이와 배터리 영향**
- **Railway 실부하 증가폭**
