import SwiftUI
import WidgetKit

// MY DRIVER / MY TEAM 위젯 — 사용자가 설정(MY PICKS)에서 고른 드라이버·팀의
// 순위·포인트를 보여주는 위젯(팀 컬러는 약어 옆 바로만, 나머지는 앱 공통 톤). Android
// FmkMyDriverWidgetProvider / FmkMyTeamWidgetProvider 의 iOS 대응.
//
// 데이터는 앱이 저장한 myDriver*/myTeam* 키만 읽는다(브리지
// _saveMyPicksPayload 와 수동 동기화). 표기는 TLA/영문 — 좁은 2×2 에서
// 한글 풀네임보다 잘 읽히고, 굿즈 같은 타이포그래피를 살린다.
// 미설정이면 "앱에서 설정" 안내 + fmkwidget://mypicks 딥링크(설정 화면).

// ── 공통: 레이아웃 ──
// 기존 일정·순위 위젯 문법을 기본으로 한다: 그라데이션 배경, 레드 킥커,
// 팀 컬러는 이름 옆 얇은 바. 여기에 팀 컬러 글로우(우상단, 은은하게)만 더해
// "내 것" 느낌을 준다 — 풀스트라이프·이탤릭 같은 장식은 쓰지 않는다.

extension View {
  /// 기본 그라데이션 위에 팀 컬러 글로우(우상단)를 얹은 위젯 배경.
  @ViewBuilder
  fileprivate func fmkMyPicksBackground(accent: Color) -> some View {
    let layer = ZStack {
      FmkTheme.background
      RadialGradient(
        colors: [accent.opacity(0.30), accent.opacity(0)],
        center: .topTrailing, startRadius: 0, endRadius: 150)
    }
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(for: .widget) { layer }
    } else {
      background(layer)
    }
  }
}

private struct FmkPlainLayout<Content: View>: View {
  let compact: Bool
  @ViewBuilder let content: () -> Content

  var body: some View {
    content()
      .padding(.horizontal, compact ? 13 : 16)
      .padding(.vertical, compact ? 11 : 12)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

/// 큰 헤드라인(TLA 또는 팀 풀네임) + 왼쪽 팀 컬러 바. 바는 텍스트 높이를
/// 따라 늘어나므로 2줄 팀명("RED BULL\nRACING")에도 맞는다.
private struct FmkCodeHeadline: View {
  let code: String
  let accent: Color
  let size: CGFloat
  var lines: Int = 1
  var body: some View {
    HStack(alignment: .center, spacing: 8) {
      RoundedRectangle(cornerRadius: 1.5)
        .fill(accent)
        .frame(width: 3.5)
        .padding(.vertical, size * 0.12)
      Text(code)
        .font(.system(size: size, weight: .heavy))
        .kerning(-0.6)
        .foregroundColor(FmkTheme.white)
        .lineLimit(lines)
        .minimumScaleFactor(0.75)
        .fixedSize(horizontal: false, vertical: true)
    }
    .fixedSize(horizontal: false, vertical: true)
  }
}

/// 킥커("MY DRIVER") — 기존 위젯의 'VIA FORMULA' 킥커와 같은 레드/자간.
private struct FmkKicker: View {
  let text: String
  var body: some View {
    Text(text)
      .font(.system(size: 9, weight: .heavy))
      .kerning(0.8)
      .foregroundColor(FmkTheme.red)
  }
}

/// 순위 변동 배지('▲2'/'▼1'). 비어 있거나 '—'(변동 없음)면 그리지 않는다 —
/// 히어로 타이포 옆에 붙은 대시는 장식이 아니라 오타처럼 읽힌다.
private struct FmkChangeBadge: View {
  let label: String
  let colorArgb: Int
  var body: some View {
    if !label.isEmpty && label != "—" {
      Text(label)
        .font(.system(size: 10, weight: .heavy))
        .foregroundColor(Color(argb: colorArgb))
    }
  }
}

/// 하단 스탯 줄: 왼쪽 큰 P4, 오른쪽 138 PTS. (선두 격차는 정보 과잉이라 뺐다.)
private struct FmkStatLine: View {
  let found: Bool
  let position: Int
  let points: String
  let compact: Bool

  var body: some View {
    HStack(alignment: .lastTextBaseline, spacing: 8) {
      Text(found && position > 0 ? "P\(position)" : "—")
        .font(.system(size: compact ? 30 : 32, weight: .heavy))
        .foregroundColor(FmkTheme.white)
        .fmkMonoDigits()
      Spacer(minLength: 4)
      if found && !points.isEmpty {
        HStack(alignment: .lastTextBaseline, spacing: 3) {
          Text(points)
            .font(.system(size: compact ? 20 : 22, weight: .heavy))
            .foregroundColor(FmkTheme.white)
            .fmkMonoDigits()
          Text("PTS")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(FmkTheme.dim)
        }
      } else if !found {
        Text("순위 집계 전")
          .font(.system(size: 10, weight: .semibold))
          .foregroundColor(FmkTheme.dim)
      }
    }
  }
}

/// 미설정 안내 — 킥커 + 설정 유도. 탭하면 설정(MY PICKS)으로 간다.
private struct FmkMyPicksEmptyView: View {
  let kicker: String
  let title: String
  var body: some View {
    FmkPlainLayout(compact: true) {
      VStack(alignment: .leading, spacing: 4) {
        FmkKicker(text: kicker)
        Spacer(minLength: 0)
        Text(title)
          .font(.system(size: 16, weight: .heavy))
          .foregroundColor(FmkTheme.white)
        Text("탭해서 설정하면\n순위·포인트가 표시됩니다")
          .font(.system(size: 10.5, weight: .semibold))
          .foregroundColor(FmkTheme.dim)
          .lineSpacing(1)
        Spacer(minLength: 0)
        Text("설정 › MY PICKS")
          .font(.system(size: 9, weight: .bold))
          .foregroundColor(FmkTheme.ghost)
      }
    }
  }
}

// ── MY DRIVER ──

struct FmkMyDriverEntry: TimelineEntry {
  let date: Date
  let data: FmkMyDriverData
}

struct FmkMyDriverProvider: TimelineProvider {
  func placeholder(in context: Context) -> FmkMyDriverEntry {
    FmkMyDriverEntry(date: Date(), data: .load())
  }
  func getSnapshot(in context: Context, completion: @escaping (FmkMyDriverEntry) -> Void) {
    completion(FmkMyDriverEntry(date: Date(), data: .load()))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<FmkMyDriverEntry>) -> Void) {
    // 순위는 6시간 주기 갱신 — 앱이 저장할 때마다 updateWidget 으로 즉시 반영된다.
    completion(
      Timeline(
        entries: [FmkMyDriverEntry(date: Date(), data: .load())],
        policy: .after(Date().addingTimeInterval(6 * 3600))))
  }
}

private var fmkMyPicksFamilies: [WidgetFamily] {
  if #available(iOSApplicationExtension 16.0, *) {
    return [.systemSmall, .systemMedium, .accessoryInline, .accessoryRectangular]
  }
  return [.systemSmall, .systemMedium]
}

struct FmkMyDriverWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "FmkMyDriverWidget", provider: FmkMyDriverProvider()) { entry in
      FmkMyDriverView(entry: entry)
    }
    .configurationDisplayName("MY DRIVER")
    .description("내 드라이버의 챔피언십 순위와 포인트를 팀 컬러로 보여줍니다. 설정 › MY PICKS 에서 고르세요.")
    .supportedFamilies(fmkMyPicksFamilies)
    .contentMarginsDisabled()
  }
}

struct FmkMyDriverView: View {
  @Environment(\.widgetFamily) private var family
  let entry: FmkMyDriverEntry

  private var data: FmkMyDriverData { entry.data }
  private var accent: Color { Color(argb: data.colorArgb) }

  private var isAccessory: Bool {
    if #available(iOSApplicationExtension 16.0, *) {
      return family == .accessoryInline || family == .accessoryRectangular
    }
    return false
  }

  private var deeplink: URL? {
    URL(string: data.isSet ? "fmkwidget://standings?homeWidget" : "fmkwidget://mypicks?homeWidget")
  }

  var body: some View {
    Group {
      if isAccessory {
        if #available(iOSApplicationExtension 16.0, *) {
          accessoryBody.fmkAccessoryBackground()
        }
      } else if !data.isSet {
        FmkMyPicksEmptyView(kicker: "MY DRIVER", title: "내 드라이버")
          .fmkWidgetBackground()
      } else if family == .systemSmall {
        smallBody.fmkMyPicksBackground(accent: accent)
      } else {
        mediumBody.fmkMyPicksBackground(accent: accent)
      }
    }
    .widgetURL(deeplink)
  }

  /// 2×2: 킥커 → 큰 TLA → 영문 이름/팀 → 하단 [P4 ··· 138 PTS].
  /// 위(누구)·아래(몇 위·몇 점) 두 덩어리로 나눠 남는 폭을 양끝 정렬로 채운다.
  private var smallBody: some View {
    FmkPlainLayout(compact: true) {
      VStack(alignment: .leading, spacing: 0) {
        HStack {
          FmkKicker(text: "MY DRIVER")
          Spacer(minLength: 0)
          FmkChangeBadge(label: data.changeLabel, colorArgb: data.changeColorArgb)
        }
        Spacer(minLength: 4)
        FmkCodeHeadline(code: data.code, accent: accent, size: 38)
        Text(data.nameEn)
          .font(.system(size: 12.5, weight: .bold))
          .foregroundColor(FmkTheme.text)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
          .padding(.top, 5)
        if !data.teamEn.isEmpty {
          Text(data.teamEn)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundColor(FmkTheme.dim)
            .lineLimit(1)
            .padding(.top, 1)
        }
        Spacer(minLength: 4)
        FmkStatLine(found: data.found, position: data.position, points: data.points, compact: true)
      }
    }
  }

  /// 4×2: 좌측 아이덴티티 블록 + 우측 스탯 행(POS / PTS / GAP).
  private var mediumBody: some View {
    FmkPlainLayout(compact: false) {
      HStack(spacing: 14) {
        VStack(alignment: .leading, spacing: 0) {
          FmkKicker(text: "MY DRIVER")
          Spacer(minLength: 2)
          FmkCodeHeadline(code: data.code, accent: accent, size: 42)
          Text(data.nameEn)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(FmkTheme.text)
            .lineLimit(1)
          if !data.teamEn.isEmpty {
            Text(data.teamEn)
              .font(.system(size: 10.5, weight: .semibold))
              .foregroundColor(FmkTheme.dim)
              .lineLimit(1)
              .padding(.top, 2)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        // 우측: 순위 / 포인트 두 행(격차는 정보 과잉이라 뺐다 — 행이 높아져 숫자가 커진다).
        VStack(spacing: 6) {
          statRow(label: "POS", value: data.found && data.position > 0 ? "P\(data.position)" : "—",
                  trailing: data.changeLabel, trailingColor: Color(argb: data.changeColorArgb))
          statRow(label: "PTS", value: data.found && !data.points.isEmpty ? data.points : "—")
        }
        .frame(width: 126)
      }
    }
  }

  private func statRow(
    label: String, value: String, trailing: String = "", trailingColor: Color = FmkTheme.dim,
    valueColor: Color = FmkTheme.white
  ) -> some View {
    HStack(spacing: 6) {
      Text(label)
        .font(.system(size: 8.5, weight: .heavy))
        .kerning(0.6)
        .foregroundColor(FmkTheme.dim)
        .frame(width: 26, alignment: .leading)
      Spacer(minLength: 0)
      if !trailing.isEmpty {
        Text(trailing)
          .font(.system(size: 10, weight: .heavy))
          .foregroundColor(trailingColor)
      }
      Text(value)
        .font(.system(size: 20, weight: .heavy))
        .foregroundColor(valueColor)
        .fmkMonoDigits()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .padding(.horizontal, 12)
    .frame(maxHeight: .infinity)
    .background(RoundedRectangle(cornerRadius: 9).fill(FmkTheme.card))
  }

  @available(iOSApplicationExtension 16.0, *)
  @ViewBuilder
  private var accessoryBody: some View {
    if family == .accessoryInline {
      Text(
        data.isSet
          ? "🏎 \(data.code) \(data.found && data.position > 0 ? "P\(data.position)" : "—") · \(data.points)pts"
          : "🏎 MY DRIVER 미설정")
    } else {
      VStack(alignment: .leading, spacing: 1) {
        Text("MY DRIVER · \(data.isSet ? data.code : "—")")
          .font(.system(size: 11, weight: .heavy)).lineLimit(1)
        Text(data.isSet ? data.nameEn : "앱에서 설정하세요")
          .font(.system(size: 12, weight: .semibold)).lineLimit(1)
        if data.isSet && data.found {
          Text("P\(data.position) · \(data.points) PTS \(data.changeLabel)")
            .font(.system(size: 12, weight: .heavy)).fmkMonoDigits().lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

extension FmkMyDriverData {
  static func load() -> FmkMyDriverData { FmkPayload.myDriver() }
}

// ── MY TEAM ──

struct FmkMyTeamEntry: TimelineEntry {
  let date: Date
  let data: FmkMyTeamData
}

struct FmkMyTeamProvider: TimelineProvider {
  func placeholder(in context: Context) -> FmkMyTeamEntry {
    FmkMyTeamEntry(date: Date(), data: .load())
  }
  func getSnapshot(in context: Context, completion: @escaping (FmkMyTeamEntry) -> Void) {
    completion(FmkMyTeamEntry(date: Date(), data: .load()))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<FmkMyTeamEntry>) -> Void) {
    completion(
      Timeline(
        entries: [FmkMyTeamEntry(date: Date(), data: .load())],
        policy: .after(Date().addingTimeInterval(6 * 3600))))
  }
}

struct FmkMyTeamWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "FmkMyTeamWidget", provider: FmkMyTeamProvider()) { entry in
      FmkMyTeamView(entry: entry)
    }
    .configurationDisplayName("MY TEAM")
    .description("내 팀의 컨스트럭터 순위·포인트와 소속 드라이버를 팀 컬러로 보여줍니다. 설정 › MY PICKS 에서 고르세요.")
    .supportedFamilies(fmkMyPicksFamilies)
    .contentMarginsDisabled()
  }
}

struct FmkMyTeamView: View {
  @Environment(\.widgetFamily) private var family
  let entry: FmkMyTeamEntry

  private var data: FmkMyTeamData { entry.data }
  private var accent: Color { Color(argb: data.colorArgb) }

  private var isAccessory: Bool {
    if #available(iOSApplicationExtension 16.0, *) {
      return family == .accessoryInline || family == .accessoryRectangular
    }
    return false
  }

  private var deeplink: URL? {
    URL(string: data.isSet ? "fmkwidget://standings?homeWidget" : "fmkwidget://mypicks?homeWidget")
  }

  /// 소속 드라이버 코드 줄("LEC · HAM").
  private var driversLine: String {
    data.drivers.map { $0.code }.joined(separator: " · ")
  }

  /// 헤드라인용 팀명 — 영문 풀네임 대문자(없으면 약어).
  private var teamTitle: String {
    data.teamEn.isEmpty ? data.code : data.teamEn.uppercased()
  }

  var body: some View {
    Group {
      if isAccessory {
        if #available(iOSApplicationExtension 16.0, *) {
          accessoryBody.fmkAccessoryBackground()
        }
      } else if !data.isSet {
        FmkMyPicksEmptyView(kicker: "MY TEAM", title: "내 팀")
          .fmkWidgetBackground()
      } else if family == .systemSmall {
        smallBody.fmkMyPicksBackground(accent: accent)
      } else {
        mediumBody.fmkMyPicksBackground(accent: accent)
      }
    }
    .widgetURL(deeplink)
  }

  /// 2×2: 킥커 → 팀 풀네임(최대 2줄) → 소속 드라이버 → 하단 [P4 ··· 177 PTS].
  private var smallBody: some View {
    FmkPlainLayout(compact: true) {
      VStack(alignment: .leading, spacing: 0) {
        HStack {
          FmkKicker(text: "MY TEAM")
          Spacer(minLength: 0)
          FmkChangeBadge(label: data.changeLabel, colorArgb: data.changeColorArgb)
        }
        Spacer(minLength: 2)
        // 팀은 풀네임(대문자) — 'RED BULL RACING' 같은 긴 이름은 2줄로 접는다.
        FmkCodeHeadline(code: teamTitle, accent: accent, size: 22, lines: 2)
        if !driversLine.isEmpty {
          Text(driversLine)
            .font(.system(size: 10.5, weight: .bold))
            .foregroundColor(FmkTheme.dim)
            .lineLimit(1)
            .padding(.top, 4)
        }
        Spacer(minLength: 4)
        FmkStatLine(found: data.found, position: data.position, points: data.points, compact: true)
      }
    }
  }

  /// 4×2: 좌측 팀 블록(풀네임 + P·PTS) + 우측 소속 드라이버 2행.
  private var mediumBody: some View {
    FmkPlainLayout(compact: false) {
      HStack(spacing: 14) {
        VStack(alignment: .leading, spacing: 0) {
          FmkKicker(text: "MY TEAM")
          Spacer(minLength: 2)
          // 팀명 바로 아래에 순위·포인트를 붙여 한 덩어리로(바닥 정렬) — 한 줄짜리
          // 팀명에서 둘 사이가 벌어지면 빈 공간이 더 눈에 띈다.
          FmkCodeHeadline(code: teamTitle, accent: accent, size: 26, lines: 2)
          HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(data.found && data.position > 0 ? "P\(data.position)" : "—")
              .font(.system(size: 26, weight: .heavy))
              .foregroundColor(FmkTheme.white).fmkMonoDigits()
            if data.found && !data.points.isEmpty {
              HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(data.points)
                  .font(.system(size: 17, weight: .heavy))
                  .foregroundColor(FmkTheme.white).fmkMonoDigits()
                Text("PTS")
                  .font(.system(size: 9, weight: .bold))
                  .foregroundColor(FmkTheme.dim)
              }
            }
            FmkChangeBadge(label: data.changeLabel, colorArgb: data.changeColorArgb)
          }
          .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        VStack(spacing: 6) {
          if data.drivers.isEmpty {
            Text("드라이버 집계 전")
              .font(.system(size: 10, weight: .semibold))
              .foregroundColor(FmkTheme.dim)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .background(RoundedRectangle(cornerRadius: 9).fill(FmkTheme.card))
          } else {
            ForEach(data.drivers) { driver in
              HStack(spacing: 6) {
                Text(driver.position > 0 ? "P\(driver.position)" : "—")
                  .font(.system(size: 10, weight: .heavy))
                  .foregroundColor(FmkTheme.dim)
                  .frame(width: 22, alignment: .leading)
                  .fmkMonoDigits()
                // TLA 는 절대 줄바꿈하지 않는다(폭이 모자라면 포인트 쪽이 양보).
                Text(driver.code)
                  .font(.system(size: 17, weight: .heavy))
                  .foregroundColor(FmkTheme.white)
                  .lineLimit(1)
                  .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
                Text(driver.points.isEmpty ? "—" : driver.points)
                  .font(.system(size: 16, weight: .heavy))
                  .foregroundColor(FmkTheme.text)
                  .fmkMonoDigits()
                  .lineLimit(1)
                  .minimumScaleFactor(0.7)
              }
              .padding(.horizontal, 10)
              .frame(maxHeight: .infinity)
              .background(RoundedRectangle(cornerRadius: 9).fill(FmkTheme.card))
            }
          }
        }
        .frame(width: 126)
      }
    }
  }

  @available(iOSApplicationExtension 16.0, *)
  @ViewBuilder
  private var accessoryBody: some View {
    if family == .accessoryInline {
      Text(
        data.isSet
          ? "🏁 \(data.code) \(data.found && data.position > 0 ? "P\(data.position)" : "—") · \(data.points)pts"
          : "🏁 MY TEAM 미설정")
    } else {
      VStack(alignment: .leading, spacing: 1) {
        Text("MY TEAM · \(data.isSet ? data.code : "—")")
          .font(.system(size: 11, weight: .heavy)).lineLimit(1)
        Text(data.isSet ? data.teamEn : "앱에서 설정하세요")
          .font(.system(size: 12, weight: .semibold)).lineLimit(1)
        if data.isSet && data.found {
          Text("P\(data.position) · \(data.points) PTS \(data.changeLabel)")
            .font(.system(size: 12, weight: .heavy)).fmkMonoDigits().lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

extension FmkMyTeamData {
  static func load() -> FmkMyTeamData { FmkPayload.myTeam() }
}
