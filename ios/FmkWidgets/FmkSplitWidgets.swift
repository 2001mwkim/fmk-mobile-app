import SwiftUI
import WidgetKit

// 분리형 위젯 2종 — **현재 둘 다 FmkWidgetsBundle 에 등록돼 있지 않다.**
// 원래는 FmkHomeWidget(라이브/결과/일정 자동 전환)의 보완이었지만, 2026-08 에
// 홈 위젯에서 라이브를 걷어내면서 존재 이유가 사라졌다.
//   FmkScheduleWidget   — 일정 전용. 이제 FmkHomeWidget 과 완전히 동일해져
//                         갤러리에 "일정"이 두 개 뜨는 문제가 있어 등록 해제.
//   FmkLiveResultWidget — 라이브·결과 전용. 라이브 제거와 함께 등록 해제.
//                         세션 창 밖 폴백이 브리지 result 모드(mode == "result")
//                         를 보는데 브리지가 더는 그 모드를 저장하지 않으므로,
//                         되살리려면 FmkPayload.latestResultState() 로 바꿔야 한다.
// 코드를 지우지 않고 남겨 둔 이유: iOS 위젯의 라이브 fetch 는 WidgetKit 갱신
// 예산(하루 수십 회)에 묶여 Vercel 부담이 사실상 없다. 한도에 여유가 생기면
// FmkHomeWidget.swift 의 세션 창 fetch 블록과 함께 되살릴 수 있다.
// (파일 삭제는 Xcode 타깃 멤버십/pbxproj 수정이 필요해 보류.)

// ── 일정 전용 ──

struct FmkScheduleProvider: TimelineProvider {
  func placeholder(in context: Context) -> FmkHomeEntry {
    FmkHomeEntry(date: Date(), payload: .load(), live: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (FmkHomeEntry) -> Void) {
    completion(FmkHomeEntry(date: Date(), payload: .load(), live: nil))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<FmkHomeEntry>) -> Void) {
    // 저장 데이터만 사용. 세션 시작 경계마다 하이라이트가 넘어가도록 미래
    // 엔트리를 깔고, 주말이 끝나면(다음 GP 로 바뀌어야 하므로) 앱 브리지
    // 갱신을 기다린다 — 6시간 주기로 다시 읽는다.
    let payload = FmkPayload.load()
    let now = Date()
    var entries: [FmkHomeEntry] = [FmkHomeEntry(date: now, payload: payload, live: nil)]
    for row in payload.sessions {
      if let start = row.start, start > now {
        entries.append(FmkHomeEntry(date: start, payload: payload, live: nil))
      }
    }
    entries.sort { $0.date < $1.date }
    completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(6 * 3600))))
  }
}

struct FmkScheduleWidget: Widget {
  private var families: [WidgetFamily] {
    if #available(iOSApplicationExtension 16.0, *) {
      return [
        .systemSmall, .systemMedium,
        .accessoryInline, .accessoryCircular, .accessoryRectangular,
      ]
    }
    return [.systemSmall, .systemMedium]
  }

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "FmkScheduleWidget", provider: FmkScheduleProvider()) { entry in
      // live 가 항상 nil 이므로 FmkHomeWidgetView 는 일정 화면만 그린다.
      FmkHomeWidgetView(entry: entry)
    }
    .configurationDisplayName("일정")
    .description("다음 그랑프리 세션 일정만 보여줍니다. 라이브 중에도 바뀌지 않습니다.")
    .supportedFamilies(families)
    .contentMarginsDisabled()
  }
}

// ── 라이브 · 최근 결과 전용 ──

struct FmkLiveResultProvider: TimelineProvider {
  func placeholder(in context: Context) -> FmkHomeEntry {
    let payload = FmkPayload.load()
    return FmkHomeEntry(date: Date(), payload: payload, live: payload.storedResultState)
  }

  func getSnapshot(in context: Context, completion: @escaping (FmkHomeEntry) -> Void) {
    let payload = FmkPayload.load()
    completion(FmkHomeEntry(date: Date(), payload: payload, live: payload.storedResultState))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<FmkHomeEntry>) -> Void) {
    let payload = FmkPayload.load()
    let now = Date()
    let stored = payload.storedResultState

    // 세션 창(시작 5분 전 ~ 종료 40분 후)에서만 live.json 을 직접 fetch —
    // FmkHomeProvider 와 같은 예산 정책. 창 밖이거나 fetch 실패/노출 기한
    // 경과면 저장된 최근 결과로 폴백한다(일정으로 떨어지지 않는 점이 차이).
    if FmkHomeProvider.inLiveWindow(payload: payload, now: now) {
      Task {
        var live: FmkLiveState? = stored
        if let snapshot = await FmkLive.fetch(payload: payload),
          let state = FmkLive.displayState(snapshot: snapshot, payload: payload, now: now)
        {
          live = state
        }
        let entry = FmkHomeEntry(date: now, payload: payload, live: live)
        completion(
          Timeline(entries: [entry], policy: .after(now.addingTimeInterval(8 * 60))))
      }
      return
    }

    let entry = FmkHomeEntry(date: now, payload: payload, live: stored)
    let nextWindow = payload.sessions
      .compactMap { $0.start }
      .filter { $0 > now }
      .map { $0.addingTimeInterval(-5 * 60) }
      .min()
    let reload = min(nextWindow ?? now.addingTimeInterval(6 * 3600),
                     now.addingTimeInterval(6 * 3600))
    completion(Timeline(entries: [entry], policy: .after(max(reload, now))))
  }
}

struct FmkLiveResultWidget: Widget {
  private var families: [WidgetFamily] {
    if #available(iOSApplicationExtension 16.0, *) {
      return [
        .systemSmall, .systemMedium,
        .accessoryInline, .accessoryCircular, .accessoryRectangular,
      ]
    }
    return [.systemSmall, .systemMedium]
  }

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "FmkLiveResultWidget", provider: FmkLiveResultProvider()) { entry in
      FmkLiveResultWidgetView(entry: entry)
    }
    .configurationDisplayName("라이브 · 결과")
    .description("라이브 중에는 실시간 순위, 평소에는 가장 최근 세션의 결과를 보여줍니다.")
    .supportedFamilies(families)
    .contentMarginsDisabled()
  }
}

struct FmkLiveResultWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: FmkHomeEntry

  private var deeplink: URL? {
    // 라이브 중엔 라이브 센터, 결과/대기 상태는 홈(최근 결과 카드).
    URL(string: entry.live?.isLive == true
      ? "fmkwidget://live?homeWidget" : "fmkwidget://home?homeWidget")
  }

  private var isAccessory: Bool {
    if #available(iOSApplicationExtension 16.0, *) {
      return family == .accessoryInline || family == .accessoryCircular
        || family == .accessoryRectangular
    }
    return false
  }

  var body: some View {
    Group {
      if isAccessory {
        // 잠금화면: 라이브/결과가 있으면 그걸, 없으면 다음 세션(일정) 축약판.
        if #available(iOSApplicationExtension 16.0, *) {
          FmkLockWidgetView(entry: entry, family: family)
            .fmkAccessoryBackground()
        }
      } else if entry.payload.isEmpty {
        FmkEmptyView().fmkWidgetBackground()
      } else if let live = entry.live {
        (family == .systemSmall
          ? AnyView(FmkLiveCompactView(live: live))
          : AnyView(FmkLiveView(live: live)))
          .fmkWidgetBackground()
      } else {
        FmkResultPendingView(entry: entry, compact: family == .systemSmall)
          .fmkWidgetBackground()
      }
    }
    .widgetURL(deeplink)
  }
}

/// 라이브도 저장된 결과도 없을 때(시즌 초, 서버 장애 등) — 빈 카드 대신
/// 다음 세션 한 줄을 안내한다.
struct FmkResultPendingView: View {
  let entry: FmkHomeEntry
  let compact: Bool

  private var nextRow: FmkSessionRow? {
    let highlight = entry.payload.highlightIndex(at: entry.date)
    let index = (1...5).contains(highlight)
        && highlight <= entry.payload.sessions.count
      ? highlight - 1 : 0
    return entry.payload.sessions.indices.contains(index)
      ? entry.payload.sessions[index] : nil
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text("결과")
        .font(.system(size: compact ? 8 : 10, weight: .heavy))
        .foregroundColor(.white) // 레드 배지 위 — 양쪽 모드 공통 흰색
        .padding(.horizontal, compact ? 6 : 7)
        .padding(.vertical, compact ? 2 : 2.5)
        .background(Capsule().fill(FmkTheme.red))
      Text(entry.payload.scheduleGpName.isEmpty
        ? entry.payload.gpName : entry.payload.scheduleGpName)
        .font(.system(size: compact ? 11 : 14, weight: .bold))
        .foregroundColor(FmkTheme.text)
        .lineLimit(1)
      Spacer(minLength: 0)
      Text("결과 데이터 준비 중")
        .font(.system(size: compact ? 13 : 15, weight: .heavy))
        .foregroundColor(FmkTheme.white)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
      Text(nextRow.map { "다음 세션 \($0.name) · \($0.date) \($0.time)" } ?? "다음 세션 정보 없음")
        .font(.system(size: compact ? 10 : 11, weight: .semibold))
        .foregroundColor(FmkTheme.dim)
        .lineLimit(compact ? 2 : 1)
        .fmkMonoDigits()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(compact ? 12 : 16)
  }
}
