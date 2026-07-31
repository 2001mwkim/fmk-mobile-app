import Foundation

// App Group UserDefaults 에서 브리지 페이로드를 읽는다.
// 키 이름은 lib/services/fmk_home_widget_bridge.dart 와 수동 동기화 —
// 한쪽을 바꾸면 반드시 함께 수정할 것(Android Kotlin Provider 도 동일 키 사용).
let fmkAppGroupId = "group.kr.formulamagazine.fmk"

struct FmkSessionRow {
  let name: String
  let date: String
  let time: String
  let id: String
  let start: Date?
  let end: Date?
}

struct FmkTopRow: Identifiable {
  let position: Int
  let name: String
  let time: String
  let colorArgb: Int

  var id: Int { position }
}

struct FmkStandingRow: Identifiable {
  let position: Int
  let name: String
  let points: String
  let changeLabel: String
  let changeColorArgb: Int
  let teamColorArgb: Int

  var id: Int { position }
}

struct FmkPayload {
  let mode: String
  let gpFlag: String
  let gpName: String
  let scheduleGpFlag: String
  let scheduleGpName: String
  let scheduleRaceId: String
  let liveBadge: String
  let lapCurrent: Int
  let lapTotal: Int
  let sessionHighlightIndex: Int
  let sessions: [FmkSessionRow]
  let topThree: [FmkTopRow]
  let driverNamesKo: [String: String]
  let driverAccents: [String: Int]
  let liveJsonUrl: String

  /// 앱이 한 번도 데이터를 저장하지 않은 상태(위젯만 먼저 추가).
  var isEmpty: Bool { sessions.isEmpty && gpName.isEmpty }

  /// 저장된 하이라이트 대신 epoch 로 재계산 — 앱을 안 열어도 타임라인
  /// 엔트리 시점마다 다음 세션 표시가 맞는다. epoch 없으면 저장값 사용.
  func highlightIndex(at date: Date) -> Int {
    var sawEpoch = false
    for (index, row) in sessions.enumerated() {
      guard let start = row.start else { continue }
      sawEpoch = true
      if start > date { return index + 1 }
    }
    return sawEpoch ? 0 : sessionHighlightIndex
  }

  static func load() -> FmkPayload {
    let store = UserDefaults(suiteName: fmkAppGroupId)

    func str(_ key: String) -> String { store?.string(forKey: key) ?? "" }
    func num(_ key: String) -> Int { store?.integer(forKey: key) ?? 0 }
    func epoch(_ key: String) -> Date? {
      let ms = num(key)
      return ms > 0 ? Date(timeIntervalSince1970: Double(ms) / 1000.0) : nil
    }
    func jsonMap<T>(_ key: String) -> [String: T] {
      guard let raw = store?.string(forKey: key),
        let data = raw.data(using: .utf8),
        let decoded = try? JSONSerialization.jsonObject(with: data),
        let map = decoded as? [String: T]
      else { return [:] }
      return map
    }

    var sessions: [FmkSessionRow] = []
    for index in 1...5 {
      guard num("session\(index)Visible") == 1 else { continue }
      sessions.append(
        FmkSessionRow(
          name: str("session\(index)Name"),
          date: str("session\(index)Date"),
          time: str("session\(index)Time"),
          id: str("session\(index)Id"),
          start: epoch("session\(index)StartEpoch"),
          end: epoch("session\(index)EndEpoch")
        ))
    }

    var topThree: [FmkTopRow] = []
    for index in 1...3 {
      let name = str("p\(index)Name").trimmingCharacters(in: .whitespaces)
      guard !name.isEmpty else { continue }
      topThree.append(
        FmkTopRow(
          position: num("p\(index)Position") == 0 ? index : num("p\(index)Position"),
          name: name,
          time: str("p\(index)Time"),
          colorArgb: normalizedColor(num("p\(index)Color"))
        ))
    }

    return FmkPayload(
      mode: str("mode").isEmpty ? "default" : str("mode"),
      gpFlag: str("gpFlag"),
      gpName: str("gpName"),
      scheduleGpFlag: str("scheduleGpFlag"),
      scheduleGpName: str("scheduleGpName"),
      scheduleRaceId: str("scheduleRaceId"),
      liveBadge: str("liveBadge"),
      lapCurrent: num("lapCurrent"),
      lapTotal: num("lapTotal"),
      sessionHighlightIndex: num("sessionHighlightIndex"),
      sessions: sessions,
      topThree: topThree,
      driverNamesKo: jsonMap("driverNamesKoJson"),
      driverAccents: jsonMap("driverAccentsJson"),
      liveJsonUrl: str("liveJsonUrl")
    )
  }

  /// 순위 위젯 행(prefix: "stDriver" 또는 "stTeam") — Kotlin Provider 와 동일.
  static func standings(prefix: String) -> [FmkStandingRow] {
    let store = UserDefaults(suiteName: fmkAppGroupId)
    var rows: [FmkStandingRow] = []
    for index in 1...5 {
      let key = "\(prefix)\(index)"
      guard store?.integer(forKey: "\(key)Visible") == 1 else { continue }
      rows.append(
        FmkStandingRow(
          position: store?.integer(forKey: "\(key)Pos") ?? index,
          name: store?.string(forKey: "\(key)Name") ?? "",
          points: store?.string(forKey: "\(key)Pts") ?? "",
          changeLabel: store?.string(forKey: "\(key)Change") ?? "",
          changeColorArgb: normalizedColor(
            store?.integer(forKey: "\(key)ChangeColor") ?? 0, fallback: 0xFFA1A1AA),
          teamColorArgb: normalizedColor(store?.integer(forKey: "\(key)Color") ?? 0)
        ))
    }
    return rows
  }
}

/// 0(미저장/투명)이면 레드 폴백 — Kotlin accentColor()/rowColor() 와 동일 규칙.
private func normalizedColor(_ stored: Int, fallback: Int = 0xFFEF4444) -> Int {
  stored == 0 ? Int(Int32(bitPattern: UInt32(fallback))) : stored
}
