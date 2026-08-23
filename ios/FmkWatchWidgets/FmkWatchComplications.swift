import SwiftUI
import WidgetKit

// ── 공용 엔트리/프로바이더 ──
// 아이폰 FmkHomeProvider 와 같은 정책: 세션 창에서만 live.json fetch(8분 간격),
// 평상시에는 세션 경계에 엔트리를 미리 깔고 다음 세션 창 직전에 재로드.
struct FmkWatchEntry: TimelineEntry {
  let date: Date
  let payload: FmkPayload
  let live: FmkLiveState?
}

struct FmkWatchProvider: TimelineProvider {
  /// 라이브 fetch 가 필요한 위젯(일정·라이브)만 true. 순위/MY 는 저장 데이터만.
  var fetchesLive: Bool = false

  func placeholder(in context: Context) -> FmkWatchEntry {
    FmkWatchEntry(date: Date(), payload: .load(), live: nil)
  }
  func getSnapshot(in context: Context, completion: @escaping (FmkWatchEntry) -> Void) {
    completion(FmkWatchEntry(date: Date(), payload: .load(), live: nil))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<FmkWatchEntry>) -> Void) {
    let payload = FmkPayload.load()
    let now = Date()
    if fetchesLive && fmkInLiveWindow(payload: payload, now: now) {
      Task {
        var live: FmkLiveState? = nil
        if let snapshot = await FmkLive.fetch(payload: payload) {
          live = FmkLive.displayState(snapshot: snapshot, payload: payload, now: now)
        }
        completion(
          Timeline(
            entries: [FmkWatchEntry(date: now, payload: payload, live: live)],
            policy: .after(now.addingTimeInterval(8 * 60))))
      }
      return
    }
    var entries = [FmkWatchEntry(date: now, payload: payload, live: nil)]
    for row in payload.sessions {
      if let start = row.start, start > now {
        entries.append(FmkWatchEntry(date: start, payload: payload, live: nil))
      }
    }
    entries.sort { $0.date < $1.date }
    let nextWindow = payload.sessions.compactMap { $0.start }.filter { $0 > now }
      .map { $0.addingTimeInterval(-5 * 60) }.min()
    let reload = min(nextWindow ?? now.addingTimeInterval(6 * 3600), now.addingTimeInterval(6 * 3600))
    completion(Timeline(entries: entries, policy: .after(max(reload, now))))
  }
}

private let fmkWatchFamilies: [WidgetFamily] = [
  .accessoryInline, .accessoryCircular, .accessoryRectangular, .accessoryCorner,
]

// ── 1) 일정 · 라이브 (자동 전환) ──
struct FmkWatchScheduleWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "FmkWatchSchedule", provider: FmkWatchProvider(fetchesLive: true)) {
      FmkWatchScheduleView(entry: $0).containerBackground(for: .widget) { Color.clear }
    }
    .configurationDisplayName("일정 · 라이브")
    .description("다음 세션까지 남은 날짜와 라이브 순위")
    .supportedFamilies(fmkWatchFamilies)
  }
}

struct FmkWatchScheduleView: View {
  @Environment(\.widgetFamily) private var family
  let entry: FmkWatchEntry

  private var nextRow: FmkSessionRow? { fmkNextSessionRow(payload: entry.payload, at: entry.date) }
  private var daysLeft: Int? { fmkDaysLeft(to: nextRow?.start, from: entry.date) }
  private var dday: String { daysLeft.map { $0 == 0 ? "오늘" : "D-\($0)" } ?? "—" }

  var body: some View {
    switch family {
    case .accessoryInline:
      if let live = entry.live {
        Text(live.isLive ? "🔴 LIVE P1 \(live.rows.first?.name ?? "—")"
                         : "🏁 \(live.badgeText) P1 \(live.rows.first?.name ?? "—")")
      } else if let row = nextRow {
        Text("🏁 \(row.name) \(row.date) \(row.time)")
      } else {
        Text("🏁 비아 포뮬러")
      }
    case .accessoryCircular:
      ZStack {
        AccessoryWidgetBackground()
        VStack(spacing: 0) {
          if let live = entry.live, live.isLive {
            Text("LAP").font(.system(size: 9, weight: .heavy))
            Text("\(live.lapCurrent)").font(.system(size: 16, weight: .heavy)).monospacedDigit()
          } else {
            Text(dday).font(.system(size: 14, weight: .heavy)).monospacedDigit()
              .minimumScaleFactor(0.7)
            Text(nextRow?.name ?? "").font(.system(size: 8, weight: .semibold))
              .lineLimit(1).minimumScaleFactor(0.6)
          }
        }
      }
    case .accessoryCorner:
      // 코너: 큰 글자 1개 + 곡선 라벨(widgetLabel).
      Text(entry.live?.isLive == true ? "LIVE" : dday)
        .font(.system(size: 16, weight: .heavy)).minimumScaleFactor(0.6)
        .widgetLabel {
          if let live = entry.live {
            Text("P1 \(live.rows.first?.name ?? "—")")
          } else if let row = nextRow {
            Text("\(row.name) \(row.time)")
          } else {
            Text("비아 포뮬러")
          }
        }
    default: // rectangular
      VStack(alignment: .leading, spacing: 1) {
        if let live = entry.live {
          Text(live.isLive ? "● LIVE \(live.gpName)" : "\(live.badgeText) \(live.gpName)")
            .font(.system(size: 12, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.7)
          ForEach(live.rows.prefix(3)) { row in
            HStack(spacing: 3) {
              Text("P\(row.position)").font(.system(size: 10, weight: .heavy)).frame(width: 18, alignment: .leading)
              Text(row.name).font(.system(size: 11, weight: .semibold)).lineLimit(1)
              Spacer(minLength: 2)
              Text(row.time).font(.system(size: 10)).monospacedDigit()
            }
          }
        } else {
          Text("\(entry.payload.scheduleGpFlag) \(entry.payload.scheduleGpName)")
            .font(.system(size: 12, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.7)
          if let row = nextRow {
            Text(row.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
            Text("\(row.date) \(row.time) · \(dday)").font(.system(size: 11)).monospacedDigit()
          } else {
            Text("일정 준비 중").font(.system(size: 11))
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

// ── 2) 드라이버 순위 ──
struct FmkWatchStandingsWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "FmkWatchDriverStandings", provider: FmkWatchProvider()) { _ in
      FmkWatchStandingsView().containerBackground(for: .widget) { Color.clear }
    }
    .configurationDisplayName("드라이버 순위")
    .description("챔피언십 드라이버 순위 Top 3")
    .supportedFamilies(fmkWatchFamilies)
  }
}

struct FmkWatchStandingsView: View {
  @Environment(\.widgetFamily) private var family
  private let rows = FmkPayload.standings(prefix: "stDriver")

  var body: some View {
    let leader = rows.first
    switch family {
    case .accessoryInline:
      Text(leader.map { "🏆 P1 \($0.name) \($0.points)pt" } ?? "🏆 드라이버 순위")
    case .accessoryCircular:
      ZStack {
        AccessoryWidgetBackground()
        VStack(spacing: 0) {
          Text("P1").font(.system(size: 9, weight: .heavy))
          Text(leader?.name ?? "—").font(.system(size: 13, weight: .heavy))
            .lineLimit(1).minimumScaleFactor(0.5)
        }
      }
    case .accessoryCorner:
      Text(leader?.name ?? "—").font(.system(size: 14, weight: .heavy)).minimumScaleFactor(0.5)
        .widgetLabel { Text("P1 · \(leader?.points ?? "—") pt") }
    default:
      VStack(alignment: .leading, spacing: 1) {
        Text("드라이버 순위").font(.system(size: 11, weight: .heavy))
        if rows.isEmpty { Text("데이터 없음").font(.system(size: 11)) }
        ForEach(rows.prefix(3)) { row in
          HStack(spacing: 3) {
            Text("\(row.position)").font(.system(size: 10, weight: .heavy)).monospacedDigit()
              .frame(width: 12, alignment: .trailing)
            Text(row.name).font(.system(size: 11, weight: .semibold)).lineLimit(1)
            Spacer(minLength: 2)
            if !row.changeLabel.isEmpty { Text(row.changeLabel).font(.system(size: 9, weight: .bold)) }
            Text(row.points).font(.system(size: 10)).monospacedDigit()
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

// ── 3) MY DRIVER ──
struct FmkWatchMyDriverWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "FmkWatchMyDriver", provider: FmkWatchProvider()) { _ in
      FmkWatchMyDriverView().containerBackground(for: .widget) { Color.clear }
    }
    .configurationDisplayName("MY DRIVER")
    .description("내가 고른 드라이버의 현재 순위")
    .supportedFamilies(fmkWatchFamilies)
  }
}

struct FmkWatchMyDriverView: View {
  @Environment(\.widgetFamily) private var family
  private let data = FmkPayload.myDriver()

  private var ready: Bool { data.isSet && data.found }

  var body: some View {
    switch family {
    case .accessoryInline:
      Text(ready ? "⭐ \(data.code) P\(data.position) \(data.points)pt" : "⭐ MY DRIVER 미설정")
    case .accessoryCircular:
      ZStack {
        AccessoryWidgetBackground()
        VStack(spacing: 0) {
          Text(ready ? data.code : "MY").font(.system(size: 11, weight: .heavy))
          Text(ready ? "P\(data.position)" : "—").font(.system(size: 14, weight: .heavy)).monospacedDigit()
        }
      }
    case .accessoryCorner:
      Text(ready ? "P\(data.position)" : "—").font(.system(size: 16, weight: .heavy))
        .widgetLabel { Text(ready ? "\(data.code) · \(data.points) pt" : "MY DRIVER 미설정") }
    default:
      VStack(alignment: .leading, spacing: 1) {
        Text("MY DRIVER").font(.system(size: 10, weight: .heavy))
        if ready {
          HStack(spacing: 4) {
            Text(data.code).font(.system(size: 14, weight: .heavy))
            Text("P\(data.position)").font(.system(size: 13, weight: .heavy)).monospacedDigit()
            if !data.changeLabel.isEmpty { Text(data.changeLabel).font(.system(size: 9, weight: .bold)) }
          }
          Text("\(data.nameEn) · \(data.teamEn)").font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.7)
          Text("\(data.points) pt" + (data.gap.isEmpty ? "" : " · \(data.gap)"))
            .font(.system(size: 10)).monospacedDigit()
        } else {
          Text("아이폰 앱 설정에서\n드라이버를 선택하세요").font(.system(size: 10))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
