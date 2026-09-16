import Foundation

// Compile with the production FmkPayloadStore.swift and FmkLive.swift on macOS.
@main
struct WidgetScheduleTests {
  static func date(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
  }

  static func main() throws {
    let fp = date("2026-09-18T03:00:00Z")
    let raceStart = date("2026-09-20T05:00:00Z")
    let raceEnd = raceStart.addingTimeInterval(2 * 3600)
    let nextStart = date("2026-10-02T03:00:00Z")
    let nextEnd = nextStart.addingTimeInterval(2 * 3600)
    func session(_ id: String, _ start: Date, _ end: Date) -> [String: Any] {
      ["id": id, "name": id, "date": "KST date", "time": "12:00",
       "startEpochMs": start.timeIntervalSince1970 * 1000,
       "endEpochMs": end.timeIntervalSince1970 * 1000]
    }
    func race(_ id: String, _ end: Date, _ sessions: [[String: Any]]) -> [String: Any] {
      ["id": id, "name": id, "flag": "flag", "endEpochMs": end.timeIntervalSince1970 * 1000,
       "sessions": sessions]
    }
    let rawRaces = [
      race("second", nextEnd, [session("race", nextStart, nextEnd)]),
      race("first", raceEnd, [session("fp1", fp, fp.addingTimeInterval(3600)),
                             session("race", raceStart, raceEnd)]),
    ]
    func encode(_ value: [String: Any]) throws -> String {
      String(data: try JSONSerialization.data(withJSONObject: value), encoding: .utf8)!
    }
    let raw = try encode(["version": 1, "races": rawRaces])
    let calendar = FmkScheduleCalendar.decode(raw)!
    var source = FmkPayload(
      mode: "default", gpFlag: "old", gpName: "old", scheduleGpFlag: "old",
      scheduleGpName: "old", scheduleRaceId: "old", liveBadge: "", resultSessionLabel: "",
      lapCurrent: 0, lapTotal: 0, sessionHighlightIndex: 0, sessions: [], topThree: [],
      driverNamesKo: [:], driverAccents: [:], liveJsonUrl: "")
    source.scheduleCalendar = calendar

    // No app writes between these projections; the same snapshot spans GPs.
    assert(source.schedule(at: fp.addingTimeInterval(-1)).scheduleRaceId == "first")
    assert(source.schedule(at: raceEnd.addingTimeInterval(-1)).scheduleRaceId == "first")
    assert(source.schedule(at: raceEnd).scheduleRaceId == "second")
    assert(source.schedule(at: nextStart).scheduleRaceId == "second")
    let finished = source.schedule(at: nextEnd)
    assert(finished.sessions.isEmpty && !finished.isEmpty)
    assert(finished.nextScheduleRow(at: nextEnd) == nil)

    let first = source.schedule(at: fp)
    assert(first.nextScheduleRow(at: fp.addingTimeInterval(-1))?.id == "fp1")
    assert(first.nextScheduleRow(at: fp)?.id == "race")
    assert(first.nextScheduleRow(at: raceStart)?.id == "race")
    assert(first.nextScheduleRow(at: raceEnd) == nil) // no past FP1 fallback

    // KST midnight is 15:00 UTC, regardless of the phone's time zone.
    let beforeMidnight = date("2026-09-17T14:59:59Z")
    let midnight = beforeMidnight.addingTimeInterval(1)
    let dates = source.scheduleEntryDates(from: beforeMidnight)
    assert(dates.first == beforeMidnight && dates == dates.sorted())
    assert(Set(dates).count == dates.count)
    for boundary in [midnight, fp, raceStart, raceEnd, nextStart, nextEnd] {
      assert(dates.contains(boundary))
    }
    assert(dates.count < 100)
    let kst = FmkPayload.scheduleTimeCalendar
    assert(kst.component(.hour, from: midnight) == 0)
    assert(kst.dateComponents([.day], from: kst.startOfDay(for: beforeMidnight),
                             to: kst.startOfDay(for: fp)).day == 1)
    assert(kst.dateComponents([.day], from: kst.startOfDay(for: midnight),
                             to: kst.startOfDay(for: fp)).day == 0)
    // A delayed reload still has the next GP transition in its supplied entries.
    assert(dates.map { source.schedule(at: $0).scheduleRaceId }.contains("second"))

    assert(FmkScheduleCalendar.decode(nil) == nil)
    assert(FmkScheduleCalendar.decode("broken JSON") == nil)
    let unknownVersion = try encode(["version": 2, "races": rawRaces])
    assert(FmkScheduleCalendar.decode(unknownVersion) == nil)
    let invalid = try encode(["version": 1, "races": [race("invalid", raceEnd, [])]])
    assert(FmkScheduleCalendar.decode(invalid) == nil)
    let empty = FmkScheduleCalendar.decode(try encode(["version": 1, "races": []]))!
    assert(empty.race(at: fp) == nil)
    source.scheduleCalendar = nil
    assert(source.schedule(at: fp).scheduleRaceId == "old")
    assert(!source.scheduleEntryDates(from: beforeMidnight).isEmpty)
    print("Widget schedule native regression checks passed")
  }
}
