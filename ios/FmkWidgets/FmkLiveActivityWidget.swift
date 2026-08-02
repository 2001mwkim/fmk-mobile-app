import SwiftUI
import WidgetKit

#if canImport(ActivityKit)
  import ActivityKit

  // 라이브 세션 Live Activity — 잠금화면 배너 + 다이나믹 아일랜드.
  // 색·타이포는 홈 위젯(FmkTheme)과 동일 계열, 노란색 금지(P1 강조 레드).
  @available(iOS 16.1, *)
  struct FmkLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
      ActivityConfiguration(for: FmkLiveActivityAttributes.self) { context in
        // 잠금화면 / 배너
        FmkLiveActivityLockScreenView(state: context.state)
          .activityBackgroundTint(FmkTheme.bgBottom)
          .activitySystemActionForegroundColor(FmkTheme.white)
      } dynamicIsland: { context in
        DynamicIsland {
          DynamicIslandExpandedRegion(.leading) {
            HStack(spacing: 6) {
              FmkLiveBadge(text: context.state.badge)
              Text(context.state.sessionName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(FmkTheme.dim)
                .lineLimit(1)
            }
            .padding(.leading, 4)
          }
          DynamicIslandExpandedRegion(.trailing) {
            if context.state.lapTotal > 0 {
              HStack(spacing: 3) {
                Text("\(context.state.lapCurrent)")
                  .font(.system(size: 13, weight: .heavy))
                  .foregroundColor(FmkTheme.white)
                Text("/ \(context.state.lapTotal) LAP")
                  .font(.system(size: 10, weight: .semibold))
                  .foregroundColor(FmkTheme.dim)
              }
              .padding(.trailing, 4)
            }
          }
          DynamicIslandExpandedRegion(.bottom) {
            VStack(spacing: 4) {
              FmkLiveActivityRow(pos: 1, name: context.state.p1Name, time: context.state.p1Time)
              FmkLiveActivityRow(pos: 2, name: context.state.p2Name, time: context.state.p2Time)
              FmkLiveActivityRow(pos: 3, name: context.state.p3Name, time: context.state.p3Time)
            }
            .padding(.top, 2)
          }
        } compactLeading: {
          Circle()
            .fill(FmkTheme.red)
            .frame(width: 8, height: 8)
        } compactTrailing: {
          // 콤팩트: P1 이름(성만 잘릴 수 있어 최소 축약) 또는 랩.
          Text(
            context.state.lapTotal > 0
              ? "L\(context.state.lapCurrent)"
              : String(context.state.p1Name.prefix(4))
          )
          .font(.system(size: 12, weight: .heavy))
          .foregroundColor(FmkTheme.white)
        } minimal: {
          Circle()
            .fill(FmkTheme.red)
            .frame(width: 8, height: 8)
        }
        .keylineTint(FmkTheme.red)
      }
    }
  }

  @available(iOS 16.1, *)
  struct FmkLiveActivityLockScreenView: View {
    let state: FmkLiveActivityAttributes.ContentState

    var body: some View {
      // 업데이트 시각 표기는 뺀다(정보 대비 시각 소음) — 대신 헤더·행
      // 타이포와 간격을 키워 배너를 채운다. updatedAt 은 계약 유지
      // (서버 페이로드·스테일 판단용)하되 표시만 하지 않는다.
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 8) {
          FmkLiveBadge(text: state.badge)
          Text(state.gpName)
            .font(.system(size: 15, weight: .heavy))
            .foregroundColor(FmkTheme.white)
            .lineLimit(1)
          Text(state.sessionName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(FmkTheme.dim)
            .lineLimit(1)
          Spacer(minLength: 0)
          if state.lapTotal > 0 {
            Text("\(state.lapCurrent)")
              .font(.system(size: 15, weight: .heavy))
              .foregroundColor(FmkTheme.white)
            Text("/ \(state.lapTotal) LAP")
              .font(.system(size: 11, weight: .semibold))
              .foregroundColor(FmkTheme.dim)
          }
        }

        VStack(spacing: 6) {
          FmkLiveActivityRow(pos: 1, name: state.p1Name, time: state.p1Time)
          FmkLiveActivityRow(pos: 2, name: state.p2Name, time: state.p2Time)
          FmkLiveActivityRow(pos: 3, name: state.p3Name, time: state.p3Time)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
    }
  }

  @available(iOS 16.1, *)
  struct FmkLiveActivityRow: View {
    let pos: Int
    let name: String
    let time: String

    var body: some View {
      // 서버가 3위까지 못 채우면 빈 문자열 — 행을 그리지 않는다.
      if !name.isEmpty {
        HStack(spacing: 8) {
          Text("\(pos)")
            .font(.system(size: 14, weight: .heavy))
            .foregroundColor(pos == 1 ? FmkTheme.red : FmkTheme.dim)
            .frame(width: 14, alignment: .center)
          Text(name)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(FmkTheme.white)
            .lineLimit(1)
          Spacer(minLength: 4)
          Text(time.isEmpty ? "—" : time)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(FmkTheme.text)
        }
      }
    }
  }

  @available(iOS 16.1, *)
  struct FmkLiveBadge: View {
    let text: String

    var body: some View {
      Text(text == "LIVE" ? "LIVE" : "결과")
        .font(.system(size: 10, weight: .heavy))
        .foregroundColor(FmkTheme.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(Capsule().fill(FmkTheme.red))
    }
  }
#endif
