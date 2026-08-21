import SwiftUI
import WidgetKit

// 챔피언십 순위 위젯 — Android FmkStandingsWidgetProvider 의 iOS 대응.
// iOS 는 위젯 토글이 없으므로 드라이버/팀을 별도 위젯 종류로 나눈다
// (위젯 갤러리에서 원하는 쪽을 고른다). 데이터는 6시간 주기 서버 갱신이라
// 위젯 자체 fetch 없이 앱이 저장한 stDriver*/stTeam* 키만 읽는다.
struct FmkStandingsEntry: TimelineEntry {
  let date: Date
  let rows: [FmkStandingRow]
}

struct FmkStandingsProvider: TimelineProvider {
  let prefix: String

  func placeholder(in context: Context) -> FmkStandingsEntry {
    FmkStandingsEntry(date: Date(), rows: FmkPayload.standings(prefix: prefix))
  }

  func getSnapshot(in context: Context, completion: @escaping (FmkStandingsEntry) -> Void) {
    completion(FmkStandingsEntry(date: Date(), rows: FmkPayload.standings(prefix: prefix)))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<FmkStandingsEntry>) -> Void) {
    let entry = FmkStandingsEntry(date: Date(), rows: FmkPayload.standings(prefix: prefix))
    // 순위는 앱/서버가 6시간 주기로 갱신 — 위젯도 같은 호흡이면 충분하다.
    completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(6 * 3600))))
  }
}

/// 잠금화면 패밀리 포함 지원 목록(iOS 16+에서만 accessory 추가).
private var fmkStandingsFamilies: [WidgetFamily] {
  if #available(iOSApplicationExtension 16.0, *) {
    return [.systemSmall, .systemMedium, .accessoryInline, .accessoryRectangular]
  }
  return [.systemSmall, .systemMedium]
}

struct FmkDriverStandingsWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: "FmkDriverStandingsWidget",
      provider: FmkStandingsProvider(prefix: "stDriver")
    ) { entry in
      FmkStandingsView(title: "챔피언십 · 드라이버", entry: entry)
    }
    .configurationDisplayName("챔피언십 순위 · 드라이버")
    .description("드라이버 챔피언십 Top 5와 순위 변동을 보여줍니다.")
    .supportedFamilies(fmkStandingsFamilies)
    .contentMarginsDisabled()
  }
}

struct FmkTeamStandingsWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: "FmkTeamStandingsWidget",
      provider: FmkStandingsProvider(prefix: "stTeam")
    ) { entry in
      FmkStandingsView(title: "챔피언십 · 팀", entry: entry)
    }
    .configurationDisplayName("챔피언십 순위 · 팀")
    .description("컨스트럭터 챔피언십 Top 5와 순위 변동을 보여줍니다.")
    .supportedFamilies(fmkStandingsFamilies)
    .contentMarginsDisabled()
  }
}

struct FmkStandingsView: View {
  @Environment(\.widgetFamily) private var family
  let title: String
  let entry: FmkStandingsEntry

  /// 잠금화면(accessory) 패밀리 여부 — iOS 16 미만에선 항상 false.
  private var isAccessory: Bool {
    if #available(iOSApplicationExtension 16.0, *) {
      return family == .accessoryInline || family == .accessoryRectangular
    }
    return false
  }

  var body: some View {
    Group {
      if isAccessory {
        if #available(iOSApplicationExtension 16.0, *) {
          accessoryBody
            .fmkAccessoryBackground()
            .widgetURL(URL(string: "fmkwidget://standings?homeWidget"))
        }
      } else {
        fullBody
      }
    }
  }

  /// 잠금화면 축약판: 인라인은 선두 1명, 직사각형은 Top 3.
  @available(iOSApplicationExtension 16.0, *)
  @ViewBuilder
  private var accessoryBody: some View {
    let rows = Array(entry.rows.prefix(3))
    if family == .accessoryInline {
      Text(
        rows.first.map { "🏆 1위 \($0.name) \($0.points)pts" } ?? "🏆 비아 포뮬러"
      )
    } else {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(rows) { row in
          HStack(spacing: 4) {
            Text("\(row.position)")
              .font(.system(size: 11, weight: .heavy)).fmkMonoDigits()
            Text(row.name)
              .font(.system(size: 12, weight: .bold))
              .lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            Text(row.points)
              .font(.system(size: 11, weight: .heavy)).fmkMonoDigits()
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder
  private var fullBody: some View {
    let compact = family == .systemSmall
    let rows = compact ? Array(entry.rows.prefix(3)) : entry.rows

    // 행들이 위젯 높이를 균등하게 채운다 — 고정 spacing 만 쓰면 하단이 빈다.
    VStack(alignment: .leading, spacing: 0) {
      Text(title)
        .font(.system(size: compact ? 11 : 13, weight: .heavy))
        .foregroundColor(FmkTheme.white)
        .lineLimit(1)
        .padding(.bottom, 4)

      if rows.isEmpty {
        Spacer(minLength: 0)
        Text("앱을 한 번 실행하면\n순위가 표시됩니다")
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(FmkTheme.dim)
          .multilineTextAlignment(.leading)
        Spacer(minLength: 0)
      } else {
        ForEach(rows) { row in
          HStack(spacing: compact ? 6 : 8) {
            Text("\(row.position)")
              .font(.system(size: compact ? 12 : 13, weight: .heavy))
              .foregroundColor(row.position == 1 ? FmkTheme.red : FmkTheme.dim)
              .frame(width: 13, alignment: .center)
              .fmkMonoDigits()
            RoundedRectangle(cornerRadius: 1.5)
              .fill(Color(argb: row.teamColorArgb))
              .frame(width: 3.5, height: compact ? 12 : 15)
            Text(row.name)
              .font(.system(size: compact ? 12 : 14, weight: .bold))
              .foregroundColor(FmkTheme.white)
              .lineLimit(1)
              .minimumScaleFactor(0.8)
            Spacer(minLength: 3)
            if !compact && !row.changeLabel.isEmpty {
              Text(row.changeLabel)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(argb: row.changeColorArgb))
            }
            Text(row.points)
              .font(.system(size: compact ? 12 : 13, weight: .heavy))
              .foregroundColor(FmkTheme.text)
              .fmkMonoDigits()
            if !compact {
              Text("PTS")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(FmkTheme.dim)
            }
          }
          .frame(maxHeight: .infinity)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(.horizontal, compact ? 13 : 16)
    .padding(.vertical, compact ? 11 : 12)
    .fmkWidgetBackground()
    .widgetURL(URL(string: "fmkwidget://standings?homeWidget"))
  }
}
