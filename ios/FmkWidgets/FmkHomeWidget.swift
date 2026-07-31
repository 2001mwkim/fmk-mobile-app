import SwiftUI
import WidgetKit

// 일정·라이브 위젯 — Android FmkHomeWidgetProvider 의 iOS 대응.
// iOS 는 위젯 토글이 없으므로 상태 자동 전환으로 대신한다:
//   라이브 중 → 라이브 순위, 종료 직후(노출 기한 내) → 결과, 평상시 → 일정.
// systemMedium 이 기본(일정 5행), systemSmall 은 Android 콤팩트 대응.
struct FmkHomeEntry: TimelineEntry {
  let date: Date
  let payload: FmkPayload
  let live: FmkLiveState?
}

struct FmkHomeProvider: TimelineProvider {
  func placeholder(in context: Context) -> FmkHomeEntry {
    FmkHomeEntry(date: Date(), payload: .load(), live: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (FmkHomeEntry) -> Void) {
    completion(FmkHomeEntry(date: Date(), payload: .load(), live: nil))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<FmkHomeEntry>) -> Void) {
    let payload = FmkPayload.load()
    let now = Date()

    // 세션 창(시작 5분 전 ~ 종료 40분 후)에서만 live.json 을 직접 fetch.
    // WidgetKit 갱신 예산이 하루 수십 회라 평상시에는 네트워크를 아낀다.
    if inLiveWindow(payload: payload, now: now) {
      Task {
        var live: FmkLiveState? = nil
        if let snapshot = await FmkLive.fetch(payload: payload) {
          live = FmkLive.displayState(snapshot: snapshot, payload: payload, now: now)
        }
        let entry = FmkHomeEntry(date: now, payload: payload, live: live)
        completion(
          Timeline(entries: [entry], policy: .after(now.addingTimeInterval(8 * 60))))
      }
      return
    }

    // 평상시: 저장 데이터로 렌더. 세션 시작마다 하이라이트가 스스로 넘어가도록
    // 미래 세션 경계에 엔트리를 미리 깔아 둔다(네트워크 불필요).
    var entries: [FmkHomeEntry] = [FmkHomeEntry(date: now, payload: payload, live: nil)]
    for row in payload.sessions {
      if let start = row.start, start > now {
        entries.append(FmkHomeEntry(date: start, payload: payload, live: nil))
      }
    }
    entries.sort { $0.date < $1.date }

    // 다음 갱신: 다음 세션 창 시작 직전(없으면 6시간 후).
    let nextWindow = payload.sessions
      .compactMap { $0.start }
      .filter { $0 > now }
      .map { $0.addingTimeInterval(-5 * 60) }
      .min()
    let reload = min(nextWindow ?? now.addingTimeInterval(6 * 3600),
                     now.addingTimeInterval(6 * 3600))
    completion(Timeline(entries: entries, policy: .after(max(reload, now))))
  }

  private func inLiveWindow(payload: FmkPayload, now: Date) -> Bool {
    payload.sessions.contains { row in
      guard let start = row.start, let end = row.end else { return false }
      return now >= start.addingTimeInterval(-5 * 60)
        && now <= end.addingTimeInterval(40 * 60)
    }
  }
}

struct FmkHomeWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "FmkHomeWidget", provider: FmkHomeProvider()) { entry in
      FmkHomeWidgetView(entry: entry)
    }
    .configurationDisplayName("일정 · 라이브")
    .description("다음 그랑프리 세션 일정과 라이브 순위를 보여줍니다.")
    .supportedFamilies([.systemSmall, .systemMedium])
    .contentMarginsDisabled()
  }
}

struct FmkHomeWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: FmkHomeEntry

  private var deeplink: URL? {
    URL(string: entry.live != nil ? "fmkwidget://live?homeWidget" : "fmkwidget://home?homeWidget")
  }

  var body: some View {
    Group {
      if entry.payload.isEmpty {
        FmkEmptyView()
      } else if let live = entry.live {
        family == .systemSmall
          ? AnyView(FmkLiveCompactView(live: live))
          : AnyView(FmkLiveView(live: live))
      } else {
        family == .systemSmall
          ? AnyView(FmkScheduleCompactView(entry: entry))
          : AnyView(FmkScheduleView(entry: entry))
      }
    }
    .fmkWidgetBackground()
    .widgetURL(deeplink)
  }
}

/// 앱 실행 전(데이터 미저장) 안내 — 런처가 빈 화면을 그리지 않게 한다.
struct FmkEmptyView: View {
  var body: some View {
    VStack(spacing: 6) {
      Text("비아 포뮬러")
        .font(.system(size: 13, weight: .heavy))
        .foregroundColor(FmkTheme.white)
      Text("앱을 한 번 실행하면\n일정이 표시됩니다")
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(FmkTheme.dim)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// ── 일정 화면(Android widget_fmk_default 대응) ──

struct FmkScheduleView: View {
  let entry: FmkHomeEntry

  var body: some View {
    let payload = entry.payload
    let highlight = payload.highlightIndex(at: entry.date)
    // 행들이 위젯 높이를 균등하게 채운다(.frame(maxHeight: .infinity)) —
    // 고정 spacing 만 쓰면 systemMedium 하단이 빈 공간으로 남는다.
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 6) {
        Text(payload.scheduleGpFlag.isEmpty ? payload.gpFlag : payload.scheduleGpFlag)
          .font(.system(size: 14))
        Text(payload.scheduleGpName.isEmpty ? payload.gpName : payload.scheduleGpName)
          .font(.system(size: 15, weight: .heavy))
          .foregroundColor(FmkTheme.white)
          .lineLimit(1)
        Spacer(minLength: 0)
      }
      .padding(.bottom, 4)

      ForEach(Array(payload.sessions.enumerated()), id: \.offset) { index, row in
        let isNext = highlight == index + 1
        let isPast = highlight > index + 1 || (highlight == 0 && row.start != nil)
        HStack(spacing: 7) {
          Circle()
            .fill(FmkTheme.red)
            .frame(width: 5, height: 5)
            .opacity(isNext ? 1 : 0)
          Text(row.name)
            .font(.system(size: 13, weight: isNext ? .heavy : .semibold))
            .foregroundColor(isNext ? FmkTheme.white : (isPast ? FmkTheme.ghost : FmkTheme.text))
            .lineLimit(1)
          Spacer(minLength: 4)
          Text(row.date)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(isPast ? FmkTheme.ghost : FmkTheme.dim)
          Text(row.time)
            .font(.system(size: 14, weight: .heavy))
            .foregroundColor(isNext ? FmkTheme.red : (isPast ? FmkTheme.ghost : FmkTheme.white))
            .fmkMonoDigits()
        }
        .frame(maxHeight: .infinity)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}

struct FmkScheduleCompactView: View {
  let entry: FmkHomeEntry

  var body: some View {
    let payload = entry.payload
    let highlight = payload.highlightIndex(at: entry.date)
    // 다음 세션(하이라이트) 우선, 없으면 첫 행 — Kotlin buildCompact 와 동일.
    let index = (1...5).contains(highlight) && highlight <= payload.sessions.count
      ? highlight - 1 : 0
    let row = payload.sessions.indices.contains(index) ? payload.sessions[index] : nil

    VStack(alignment: .leading, spacing: 3) {
      Text("VIA FORMULA")
        .font(.system(size: 9, weight: .heavy))
        .foregroundColor(FmkTheme.red)
        .kerning(0.8)
      HStack(spacing: 4) {
        Text(payload.scheduleGpFlag.isEmpty ? payload.gpFlag : payload.scheduleGpFlag)
          .font(.system(size: 12))
        Text(payload.scheduleGpName.isEmpty ? payload.gpName : payload.scheduleGpName)
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(FmkTheme.text)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      Spacer(minLength: 0)
      Text(row?.name ?? "—")
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(FmkTheme.dim)
        .lineLimit(1)
      Text(row?.time ?? "—")
        .font(.system(size: 26, weight: .heavy))
        .foregroundColor(FmkTheme.white)
        .fmkMonoDigits()
      Text(row.map { $0.date.isEmpty ? "KST" : "\($0.date) · KST" } ?? "KST")
        .font(.system(size: 10, weight: .medium))
        .foregroundColor(FmkTheme.dim)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(13)
  }
}

// ── 라이브/결과 화면(Android widget_fmk_live 대응) ──

struct FmkLiveView: View {
  let live: FmkLiveState

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 7) {
        Text(live.isLive ? "LIVE" : "결과")
          .font(.system(size: 10, weight: .heavy))
          .foregroundColor(FmkTheme.white)
          .padding(.horizontal, 7)
          .padding(.vertical, 2.5)
          .background(Capsule().fill(FmkTheme.red))
        Text(live.gpName)
          .font(.system(size: 14, weight: .heavy))
          .foregroundColor(FmkTheme.white)
          .lineLimit(1)
        Spacer(minLength: 0)
        if live.isLive && live.lapTotal > 0 {
          Text("\(live.lapCurrent)")
            .font(.system(size: 14, weight: .heavy))
            .foregroundColor(FmkTheme.white)
            .fmkMonoDigits()
          Text("/ \(live.lapTotal) LAP")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(FmkTheme.dim)
        }
      }
      .padding(.bottom, 6)

      // 순위 행이 남은 높이를 균등하게 나눠 위젯을 가득 채운다.
      ForEach(live.rows) { row in
        HStack(spacing: 8) {
          Text("\(row.position)")
            .font(.system(size: 14, weight: .heavy))
            .foregroundColor(FmkTheme.dim)
            .frame(width: 14, alignment: .center)
            .fmkMonoDigits()
          RoundedRectangle(cornerRadius: 1.5)
            .fill(Color(argb: row.colorArgb))
            .frame(width: 3.5, height: 16)
          Text(row.name)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(FmkTheme.white)
            .lineLimit(1)
          Spacer(minLength: 4)
          Text(row.time.isEmpty ? "—" : row.time)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(FmkTheme.text)
            .fmkMonoDigits()
        }
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 9).fill(FmkTheme.card))
        .padding(.vertical, 2)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}

struct FmkLiveCompactView: View {
  let live: FmkLiveState

  var body: some View {
    let leader = live.rows.first
    VStack(alignment: .leading, spacing: 3) {
      Text(live.isLive ? "LIVE" : "결과")
        .font(.system(size: 8, weight: .heavy))
        .foregroundColor(FmkTheme.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(FmkTheme.red))
      Text(live.gpName)
        .font(.system(size: 11, weight: .bold))
        .foregroundColor(FmkTheme.text)
        .lineLimit(1)
      Spacer(minLength: 0)
      Text(live.isLive ? "P1" : "우승")
        .font(.system(size: 10, weight: .semibold))
        .foregroundColor(FmkTheme.dim)
      Text(leader?.name ?? "—")
        .font(.system(size: 16, weight: .heavy))
        .foregroundColor(FmkTheme.white)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(
        live.isLive && live.lapTotal > 0
          ? "LAP \(live.lapCurrent) / \(live.lapTotal)"
          : (leader?.time.isEmpty == false ? leader!.time : "—")
      )
      .font(.system(size: 10, weight: .semibold))
      .foregroundColor(FmkTheme.dim)
      .fmkMonoDigits()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(12)
  }
}
