import Foundation

// live.json fetch + 표시 정책의 최소 포팅.
// 원본 규칙: lib/models/live_session.dart / lib/services/live_session_service.dart.
// 위젯은 Top 3 만 그리므로 전체 classification·섹터 등은 파싱하지 않는다.
//
// 표시 정책(CLAUDE.md 라이브 표시 규칙과 동일):
// - Race/Sprint 는 interval 만(없으면 '—', gapToLeader 폴백 금지)
// - Practice/Qualifying 은 랩타임만(displayTime → lapTime, 없으면 '—')
// - 세션 종료 노출 기한: 다음 세션 30분 전까지(마지막 세션은 +1시간)
// - 퀄리파잉 계열만 세그먼트(Q1/Q2) 사이 ended 를 LIVE 로 보정

struct FmkLiveDriver {
  let position: Int
  let code: String
  let displayName: String
  let interval: String?
  let displayTime: String?
  let lapTime: String?
}

struct FmkLiveSnapshot {
  let status: String
  let raceId: String?
  let raceName: String?
  let sessionType: String?
  let sessionName: String?
  let currentLap: Int?
  let totalLaps: Int?
  let endedAt: Date?
  let visibleUntil: Date?
  let topThree: [FmkLiveDriver]

  /// lib/models/live_session.dart 의 liveTextIsRaceOrSprint 포팅.
  var isRaceOrSprint: Bool {
    let text = "\(sessionType ?? "") \(sessionName ?? "")".lowercased()
    if text.contains("practice") || text.contains("qualifying")
      || text.contains("shootout") || text.contains("프랙티스") || text.contains("퀄리")
    {
      return false
    }
    return text.contains("race") || text.contains("sprint")
      || text.contains("레이스") || text.contains("스프린트")
  }

  /// liveRaceSessionForSnapshot 의 세션 id 매칭 포팅(races.dart 세션 id).
  var sessionId: String? {
    let text = "\(sessionType ?? "") \(sessionName ?? "")".lowercased()
    if text.contains("practice 1") || text.contains("free practice 1")
      || text.contains("fp1") || text.contains("프랙티스 1")
    {
      return "fp1"
    }
    if text.contains("practice 2") || text.contains("free practice 2")
      || text.contains("fp2") || text.contains("프랙티스 2")
    {
      return "fp2"
    }
    if text.contains("practice 3") || text.contains("free practice 3")
      || text.contains("fp3") || text.contains("프랙티스 3")
    {
      return "fp3"
    }
    let sprint = text.contains("sprint") || text.contains("스프린트")
    let qualifying =
      text.contains("qualifying") || text.contains("shootout") || text.contains("퀄리")
    if sprint && qualifying { return "sprint_qualifying" }
    if sprint { return "sprint" }
    if qualifying { return "qualifying" }
    if text.contains("race") || text.contains("레이스") { return "race" }
    return nil
  }
}

/// 위젯이 실제로 그릴 라이브/결과 화면 상태.
struct FmkLiveState {
  let badge: String  // "LIVE" | "RESULT"
  let gpName: String
  let lapCurrent: Int
  let lapTotal: Int
  let rows: [FmkTopRow]
  /// 결과 배지 앞에 붙는 세션 라벨("FP2 결과"). 비어 있으면 "결과"만 표기.
  var sessionLabel: String = ""

  var isLive: Bool { badge == "LIVE" }

  /// 헤더 배지 텍스트 — 라이브는 항상 "LIVE".
  var badgeText: String {
    if isLive { return "LIVE" }
    return sessionLabel.isEmpty ? "결과" : "\(sessionLabel) 결과"
  }
}

enum FmkLive {
  /// 프로덕션 collector — 브리지 저장값(liveJsonUrl)이 없을 때의 폴백.
  /// lib/services/live_session_service.dart 의 릴리스 기본값과 동일.
  static let fallbackUrl = "https://live-production-c03d.up.railway.app/live.json"

  static func fetch(payload: FmkPayload) async -> FmkLiveSnapshot? {
    let raw = payload.liveJsonUrl.isEmpty ? fallbackUrl : payload.liveJsonUrl
    guard let url = URL(string: raw) else { return nil }
    var request = URLRequest(url: url)
    request.timeoutInterval = 8
    guard let (data, response) = try? await URLSession.shared.data(for: request),
      let http = response as? HTTPURLResponse, http.statusCode == 200
    else { return nil }
    return parse(data: data)
  }

  static func parse(data: Data) -> FmkLiveSnapshot? {
    guard let decoded = try? JSONSerialization.jsonObject(with: data),
      let root = decoded as? [String: Any]
    else { return nil }
    // collector 는 { snapshot, collector } 로 감싸지만 snapshot 단독도 허용.
    let map = (root["snapshot"] as? [String: Any]) ?? root

    func str(_ key: String) -> String? { map[key] as? String }
    func num(_ key: String) -> Int? {
      if let value = map[key] as? Int { return value }
      if let value = map[key] as? Double { return Int(value) }
      return nil
    }
    func date(_ key: String) -> Date? {
      guard let raw = str(key) else { return nil }
      return parseISO(raw)
    }

    var drivers: [FmkLiveDriver] = []
    if let list = map["topThree"] as? [[String: Any]] {
      for item in list.prefix(3) {
        guard let position = (item["position"] as? Int) ?? (item["position"] as? Double).map(Int.init)
        else { continue }
        drivers.append(
          FmkLiveDriver(
            position: position,
            code: (item["code"] as? String) ?? "?",
            displayName: (item["displayName"] as? String) ?? "Unknown",
            interval: item["interval"] as? String,
            displayTime: item["displayTime"] as? String,
            lapTime: item["lapTime"] as? String
          ))
      }
    }

    guard let status = str("status") else { return nil }
    return FmkLiveSnapshot(
      status: status,
      raceId: str("raceId"),
      raceName: str("raceName"),
      sessionType: str("sessionType"),
      sessionName: str("sessionName"),
      currentLap: num("currentLap"),
      totalLaps: num("totalLaps"),
      endedAt: date("endedAt"),
      visibleUntil: date("visibleUntil"),
      topThree: drivers
    )
  }

  /// 스냅샷 → 표시 상태. 노출 기한이 지났으면 nil(일정 화면으로 폴백).
  static func displayState(
    snapshot: FmkLiveSnapshot, payload: FmkPayload, now: Date
  ) -> FmkLiveState? {
    let active = isSessionActive(snapshot: snapshot, payload: payload, now: now)
    if !active {
      guard snapshot.status == "ended" else { return nil }
      guard let until = resultVisibleUntil(snapshot: snapshot, payload: payload),
        now < until
      else { return nil }
    }

    let raceLike = snapshot.isRaceOrSprint
    let rows: [FmkTopRow] = snapshot.topThree.compactMap { driver in
      let code = driver.code.trimmingCharacters(in: .whitespaces).uppercased()
      guard !code.isEmpty, code != "?" else { return nil }
      // 표시 규칙: race/sprint 는 interval, 그 외 랩타임 — 폴백 금지.
      let time = raceLike
        ? (driver.interval ?? "—")
        : (driver.displayTime ?? driver.lapTime ?? "—")
      return FmkTopRow(
        position: driver.position,
        name: payload.driverNamesKo[code] ?? driver.displayName,
        time: time,
        colorArgb: payload.driverAccents[code]
          ?? Int(Int32(bitPattern: 0xFFEF4444)),
        code: code
      )
    }

    let gpName = [snapshot.raceName, payload.gpName, "비아 포뮬러 라이브"]
      .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
      .first { !$0.isEmpty } ?? ""
    return FmkLiveState(
      badge: active ? "LIVE" : "RESULT",
      gpName: gpName,
      lapCurrent: max(snapshot.currentLap ?? 0, 0),
      lapTotal: max(snapshot.totalLaps ?? 0, 0),
      rows: rows
    )
  }

  /// isLiveSnapshotSessionActive 포팅 — 퀄리파잉 계열만 세그먼트 사이
  /// ended 를 스케줄 창 기준으로 LIVE 보정한다.
  static func isSessionActive(
    snapshot: FmkLiveSnapshot, payload: FmkPayload, now: Date
  ) -> Bool {
    if snapshot.status == "live" { return true }
    guard snapshot.status == "ended" else { return false }
    guard let sessionId = snapshot.sessionId,
      sessionId == "qualifying" || sessionId == "sprint_qualifying",
      let row = matchedScheduleRow(snapshot: snapshot, payload: payload),
      let start = row.start, let end = row.end
    else { return false }
    return now >= start && now < end
  }

  /// 종료 결과 노출 기한: 다음 세션 30분 전까지, 마지막 세션은 종료 +1시간.
  /// 스케줄 매칭 실패 시 collector 의 visibleUntil → endedAt+30분 순 폴백
  /// (isLiveSnapshotDisplayable 의 안전 폴백과 동일한 취지).
  static func resultVisibleUntil(
    snapshot: FmkLiveSnapshot, payload: FmkPayload
  ) -> Date? {
    if let row = matchedScheduleRow(snapshot: snapshot, payload: payload),
      let index = payload.sessions.firstIndex(where: { $0.id == row.id })
    {
      let next = payload.sessions.dropFirst(index + 1).first { $0.start != nil }
      if let nextStart = next?.start {
        return nextStart.addingTimeInterval(-30 * 60)
      }
      if let ended = snapshot.endedAt ?? row.end {
        return ended.addingTimeInterval(60 * 60)
      }
    }
    if let until = snapshot.visibleUntil { return until }
    if let ended = snapshot.endedAt { return ended.addingTimeInterval(30 * 60) }
    return nil
  }

  /// 스냅샷 세션 ↔ 저장된 일정 행 매칭. 저장된 일정은 '다음 그랑프리'라서,
  /// 라이브 중인 그랑프리와 다르면(주말 종료 후 등) 매칭하지 않는다.
  static func matchedScheduleRow(
    snapshot: FmkLiveSnapshot, payload: FmkPayload
  ) -> FmkSessionRow? {
    guard let raceId = snapshot.raceId, !payload.scheduleRaceId.isEmpty,
      raceId == payload.scheduleRaceId,
      let sessionId = snapshot.sessionId
    else { return nil }
    return payload.sessions.first { $0.id == sessionId }
  }
}

/// ISO8601(소수초 유무 모두) 파싱.
func parseISO(_ raw: String) -> Date? {
  let withFraction = ISO8601DateFormatter()
  withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  if let parsed = withFraction.date(from: raw) { return parsed }
  let plain = ISO8601DateFormatter()
  plain.formatOptions = [.withInternetDateTime]
  return plain.date(from: raw)
}
