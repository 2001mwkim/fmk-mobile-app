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

// Codable uses Double for epochs, including on the 32-bit watch architecture.
struct FmkScheduleCalendar: Decodable {
  let version: Int
  let races: [FmkCalendarRace]

  static func decode(_ raw: String?) -> FmkScheduleCalendar? {
    guard let data = raw?.data(using: .utf8),
      let value = try? JSONDecoder().decode(Self.self, from: data),
      value.version == 1,
      value.races.allSatisfy({ race in
        !race.id.isEmpty && !race.sessions.isEmpty && race.sessions.count <= 5
          && race.endEpochMs.isFinite && race.endEpochMs > 0
          && race.sessions.allSatisfy {
            $0.startEpochMs.isFinite && $0.endEpochMs.isFinite
              && $0.startEpochMs > 0 && $0.endEpochMs > $0.startEpochMs
              && $0.endEpochMs <= race.endEpochMs
          }
      })
    else { return nil }
    return value
  }

  func race(at date: Date) -> FmkCalendarRace? {
    races.filter { $0.end > date }.min { $0.start < $1.start }
  }
}

struct FmkCalendarRace: Decodable {
  let id: String
  let name: String
  let flag: String
  let endEpochMs: Double
  let sessions: [FmkCalendarSession]
  var start: Date { sessions.map { $0.row.start! }.min()! }
  var end: Date { Date(timeIntervalSince1970: endEpochMs / 1000) }
}

struct FmkCalendarSession: Decodable {
  let id: String
  let name: String
  let date: String
  let time: String
  let startEpochMs: Double
  let endEpochMs: Double
  var row: FmkSessionRow {
    FmkSessionRow(
      name: name, date: date, time: time, id: id,
      start: Date(timeIntervalSince1970: startEpochMs / 1000),
      end: Date(timeIntervalSince1970: endEpochMs / 1000))
  }
}

struct FmkTopRow: Identifiable {
  let position: Int
  let name: String
  let time: String
  let colorArgb: Int
  /// 드라이버 TLA(라이브 행만 채워짐, 저장 행은 "") — 워치 원형 컴플리케이션용.
  var code: String = ""

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

/// MY DRIVER 위젯 데이터(myDriver* 키). 브리지 _saveMyPicksPayload 와 동기화.
struct FmkMyDriverData {
  let isSet: Bool
  let found: Bool
  let code: String
  let nameEn: String
  let nameKo: String
  let teamKo: String
  let teamEn: String
  let position: Int
  let points: String
  let gap: String
  let changeLabel: String
  let changeColorArgb: Int
  let colorArgb: Int
}

/// MY TEAM 위젯 소속 드라이버 한 줄(myTeamD{n}* 키).
struct FmkMyTeamDriver: Identifiable {
  let code: String
  let position: Int
  let points: String
  var id: String { code }
}

/// MY TEAM 위젯 데이터(myTeam* 키). 브리지 _saveMyPicksPayload 와 동기화.
struct FmkMyTeamData {
  let isSet: Bool
  let found: Bool
  let teamKo: String
  let teamEn: String
  let code: String
  let position: Int
  let points: String
  let gap: String
  let changeLabel: String
  let changeColorArgb: Int
  let colorArgb: Int
  let drivers: [FmkMyTeamDriver]
}

struct FmkPayload {
  let mode: String
  let gpFlag: String
  let gpName: String
  let scheduleGpFlag: String
  let scheduleGpName: String
  let scheduleRaceId: String
  let liveBadge: String
  /// result 모드의 세션 라벨('레이스'/'퀄리파잉'/'FP2' …, 다른 모드는 "").
  let resultSessionLabel: String
  let lapCurrent: Int
  let lapTotal: Int
  let sessionHighlightIndex: Int
  let sessions: [FmkSessionRow]
  let topThree: [FmkTopRow]
  let driverNamesKo: [String: String]
  let driverAccents: [String: Int]
  let liveJsonUrl: String
  var scheduleCalendar: FmkScheduleCalendar? = nil

  static var scheduleTimeCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return calendar
  }

  /// Project the saved season at the entry's date, not the app's last launch.
  /// A missing/invalid new snapshot retains compatibility with older installs.
  func schedule(at date: Date) -> FmkPayload {
    guard let calendar = scheduleCalendar else { return self }
    let race = calendar.race(at: date)
    return FmkPayload(
      mode: "default", gpFlag: race?.flag ?? "", gpName: race?.name ?? "일정 종료",
      scheduleGpFlag: race?.flag ?? "", scheduleGpName: race?.name ?? "일정 종료",
      scheduleRaceId: race?.id ?? "", liveBadge: "", resultSessionLabel: "",
      lapCurrent: 0, lapTotal: 0, sessionHighlightIndex: 0,
      sessions: race?.sessions.map { $0.row }.sorted { $0.start! < $1.start! } ?? [],
      topThree: [], driverNamesKo: driverNamesKo, driverAccents: driverAccents,
      liveJsonUrl: liveJsonUrl)
  }

  /// Pre-render 35 days of changes; reload daily to extend this safety margin.
  /// No network or app execution is required when WidgetKit asks for a timeline.
  func scheduleEntryDates(from now: Date) -> [Date] {
    let calendar = Self.scheduleTimeCalendar
    let horizon = calendar.date(byAdding: .day, value: 35, to: now)!
    var dates: Set<Date> = [now]
    var midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
    while midnight <= horizon {
      dates.insert(midnight)
      midnight = calendar.date(byAdding: .day, value: 1, to: midnight)!
    }
    let rows = scheduleCalendar?.races.flatMap { $0.sessions.map { $0.row } } ?? sessions
    let boundaries = rows.flatMap { [$0.start, $0.end].compactMap { $0 } }
      + (scheduleCalendar?.races.map { $0.end } ?? [])
    for date in boundaries where date > now && date <= horizon { dates.insert(date) }
    return dates.sorted()
  }

  /// 강조할 세션 인덱스(0-based). 일정 화면·콤팩트·잠금화면이 같은 규칙을
  /// 쓰도록 여기서만 판정한다 — 패밀리마다 다르게 고르면 레이스 중에 작은
  /// 위젯은 "레이스", 중형은 아무것도 강조하지 않는 상태가 된다.
  func nextScheduleIndex(at date: Date) -> Int? {
    let highlight = highlightIndex(at: date)
    if highlight > 0 && highlight <= sessions.count { return highlight - 1 }
    // The final race remains visible while running, never rewind to past FP1.
    return sessions.firstIndex {
      guard let start = $0.start, let end = $0.end else { return false }
      return start <= date && date < end
    }
  }

  func nextScheduleRow(at date: Date) -> FmkSessionRow? {
    nextScheduleIndex(at: date).map { sessions[$0] }
  }

  /// 앱이 한 번도 데이터를 저장하지 않은 상태(위젯만 먼저 추가).
  var isEmpty: Bool { sessions.isEmpty && gpName.isEmpty }

  /// 브리지가 저장한 최근 확정 결과(mode == "result", p1~p3) → 표시 상태.
  /// 라이브·결과 전용 위젯이 세션 창 밖에서 그린다. 결과가 없으면 nil.
  var storedResultState: FmkLiveState? {
    guard mode == "result", !topThree.isEmpty else { return nil }
    return FmkLiveState(
      badge: "RESULT", gpName: gpName, lapCurrent: 0, lapTotal: 0,
      rows: topThree, sessionLabel: resultSessionLabel)
  }

  /// 최근 확정 결과(lr* 키, 브리지 _saveLatestResultExtras — iOS 에서 항상 저장).
  /// mode 와 무관하게 읽히므로 워치 앱이 라이브/결과 창 밖에서 "최근 세션 결과"로
  /// 쓴다. 없으면 nil.
  static func latestResultState() -> FmkLiveState? {
    let store = UserDefaults(suiteName: fmkAppGroupId)
    func str(_ key: String) -> String { store?.string(forKey: key) ?? "" }
    func num(_ key: String) -> Int { store?.integer(forKey: key) ?? 0 }
    let gpName = str("lrGpName")
    guard !gpName.isEmpty else { return nil }
    var rows: [FmkTopRow] = []
    for index in 1...3 {
      let name = str("lr\(index)Name").trimmingCharacters(in: .whitespaces)
      guard !name.isEmpty else { continue }
      rows.append(
        FmkTopRow(
          position: num("lr\(index)Pos") == 0 ? index : num("lr\(index)Pos"),
          name: name, time: str("lr\(index)Time"),
          colorArgb: normalizedColor(num("lr\(index)Color"))))
    }
    guard !rows.isEmpty else { return nil }
    return FmkLiveState(
      badge: "RESULT", gpName: "\(str("lrGpFlag")) \(gpName)".trimmingCharacters(in: .whitespaces),
      lapCurrent: 0, lapTotal: 0, rows: rows, sessionLabel: str("lrLabel"))
  }

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
    // epoch 밀리초는 반드시 double 로 읽는다 — 워치 실기기(arm64_32)는 Int 가
    // 32비트라 integer(forKey:) 가 1.78e12 를 잘라먹고 1970년 날짜를 만든다
    // (그러면 다음 세션이 항상 과거로 보여 D-day 가 D-DAY 로 굳는다).
    // 시뮬레이터(64비트)에서는 재현되지 않으니 주의.
    func epoch(_ key: String) -> Date? {
      let ms = store?.double(forKey: key) ?? 0
      return ms > 0 ? Date(timeIntervalSince1970: ms / 1000.0) : nil
    }
    // ARGB 값(0xFF……)은 Int32 범위를 넘어서, 워치(arm64_32)에서는
    // [String: Int] 캐스팅이 통째로 실패해 팀 컬러가 전부 폴백 레드가 된다.
    // NSNumber 로 받아 비트 패턴만 옮긴다(Color(argb:) 가 다시 UInt32 로 읽음).
    func colorMap(_ key: String) -> [String: Int] {
      guard let raw = store?.string(forKey: key),
        let data = raw.data(using: .utf8),
        let decoded = try? JSONSerialization.jsonObject(with: data),
        let map = decoded as? [String: Any]
      else { return [:] }
      var out: [String: Int] = [:]
      for (code, value) in map {
        guard let number = value as? NSNumber else { continue }
        out[code] = Int(Int32(truncatingIfNeeded: number.int64Value))
      }
      return out
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
      resultSessionLabel: str("resultSessionLabel"),
      lapCurrent: num("lapCurrent"),
      lapTotal: num("lapTotal"),
      sessionHighlightIndex: num("sessionHighlightIndex"),
      sessions: sessions,
      topThree: topThree,
      driverNamesKo: jsonMap("driverNamesKoJson"),
      driverAccents: colorMap("driverAccentsJson"),
      liveJsonUrl: str("liveJsonUrl"),
      scheduleCalendar: FmkScheduleCalendar.decode(store?.string(forKey: "scheduleCalendarV1"))
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

extension FmkPayload {
  /// MY DRIVER 위젯 데이터 — Kotlin FmkMyDriverWidgetProvider 와 동일 키.
  static func myDriver() -> FmkMyDriverData {
    let store = UserDefaults(suiteName: fmkAppGroupId)
    func str(_ key: String) -> String { store?.string(forKey: key) ?? "" }
    func num(_ key: String) -> Int { store?.integer(forKey: key) ?? 0 }
    return FmkMyDriverData(
      isSet: num("myDriverSet") == 1,
      found: num("myDriverFound") == 1,
      code: str("myDriverCode"),
      nameEn: str("myDriverNameEn"),
      nameKo: str("myDriverNameKo"),
      teamKo: str("myDriverTeamKo"),
      teamEn: str("myDriverTeamEn"),
      position: num("myDriverPos"),
      points: str("myDriverPts"),
      gap: str("myDriverGap"),
      changeLabel: str("myDriverChange"),
      changeColorArgb: normalizedColor(num("myDriverChangeColor"), fallback: 0xFFA1A1AA),
      colorArgb: normalizedColor(num("myDriverColor"))
    )
  }

  /// MY TEAM 위젯 데이터 — Kotlin FmkMyTeamWidgetProvider 와 동일 키.
  static func myTeam() -> FmkMyTeamData {
    let store = UserDefaults(suiteName: fmkAppGroupId)
    func str(_ key: String) -> String { store?.string(forKey: key) ?? "" }
    func num(_ key: String) -> Int { store?.integer(forKey: key) ?? 0 }
    var drivers: [FmkMyTeamDriver] = []
    for index in 1...2 {
      let code = str("myTeamD\(index)Code")
      guard !code.isEmpty else { continue }
      drivers.append(
        FmkMyTeamDriver(
          code: code, position: num("myTeamD\(index)Pos"), points: str("myTeamD\(index)Pts")))
    }
    return FmkMyTeamData(
      isSet: num("myTeamSet") == 1,
      found: num("myTeamFound") == 1,
      teamKo: str("myTeamKo"),
      teamEn: str("myTeamEn"),
      code: str("myTeamCode"),
      position: num("myTeamPos"),
      points: str("myTeamPts"),
      gap: str("myTeamGap"),
      changeLabel: str("myTeamChange"),
      changeColorArgb: normalizedColor(num("myTeamChangeColor"), fallback: 0xFFA1A1AA),
      colorArgb: normalizedColor(num("myTeamColor")),
      drivers: drivers
    )
  }
}

/// 0(미저장/투명)이면 레드 폴백 — Kotlin accentColor()/rowColor() 와 동일 규칙.
/// fallback 은 UInt32 — 워치 실기기(arm64_32)는 Int 가 32비트라 0xFF… 리터럴이
/// Int 파라미터로 들어가면 오버플로 컴파일 에러가 난다.
private func normalizedColor(_ stored: Int, fallback: UInt32 = 0xFFEF4444) -> Int {
  stored == 0 ? Int(Int32(bitPattern: fallback)) : stored
}
