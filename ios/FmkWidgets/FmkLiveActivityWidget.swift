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
            .fmkIslandScheme()
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
              .fmkIslandScheme()
            }
          }
          DynamicIslandExpandedRegion(.bottom) {
            VStack(spacing: 4) {
              FmkLiveActivityRow(pos: 1, name: context.state.p1Name, time: context.state.p1Time)
              FmkLiveActivityRow(pos: 2, name: context.state.p2Name, time: context.state.p2Time)
              FmkLiveActivityRow(pos: 3, name: context.state.p3Name, time: context.state.p3Time)
            }
            .padding(.top, 2)
            .fmkIslandScheme()
          }
        } compactLeading: {
          // 콤팩트 왼쪽: 빨간 점 + 세션 약어(FP2/Q/SQ/SPR) 또는 현재 랩(L23).
          // 콤팩트 영역은 좌우 합쳐 ~90pt 라 한글은 넣지 않는다(영문 ≤4자).
          HStack(spacing: 4) {
            Circle()
              .fill(FmkTheme.red)
              .frame(width: 7, height: 7)
            Text(context.state.compactLeadingText)
              .font(.system(size: 11, weight: .heavy))
              .foregroundColor(FmkTheme.white)
              .lineLimit(1)
              .minimumScaleFactor(0.8)
          }
          .fmkIslandScheme()
        } compactTrailing: {
          // 콤팩트 오른쪽: "P1" + 선두 드라이버 TLA(예: P1 VER).
          HStack(spacing: 3) {
            Text("P1")
              .font(.system(size: 10, weight: .heavy))
              .foregroundColor(FmkTheme.red)
            Text(context.state.compactP1Code)
              .font(.system(size: 12, weight: .heavy))
              .foregroundColor(FmkTheme.white)
          }
          .lineLimit(1)
          .minimumScaleFactor(0.8)
          .fmkIslandScheme()
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
        .foregroundColor(.white) // 레드 배지 위 — 양쪽 모드 공통 흰색
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(Capsule().fill(FmkTheme.red))
    }
  }
  // 다이나믹 아일랜드 콤팩트 표시용 파생 문자열.
  @available(iOS 16.1, *)
  extension FmkLiveActivityAttributes.ContentState {
    /// 레이스/스프린트는 현재 랩(L23), 그 외에는 세션 약어.
    var compactLeadingText: String {
      if lapTotal > 0 { return "L\(lapCurrent)" }
      return FmkLiveActivityAttributes.ContentState.sessionAbbrev(sessionName)
    }

    /// P1 TLA. 구버전 페이로드(p1Code 없음)면 이름 앞 3자를 대문자로 — 영문
    /// 이름이면 그럭저럭, 한글이면 최소한 잘림 없이 3자만 보인다.
    var compactP1Code: String {
      let code = (p1Code ?? "").trimmingCharacters(in: .whitespaces)
      if !code.isEmpty { return code.uppercased() }
      return String(p1Name.prefix(3)).uppercased()
    }

    /// 한글 세션명(liveSessionLabelKo 출력) → 영문 약어. 콤팩트 폭 제약으로
    /// 4자 이하. 매핑 안 되면 원문 앞 4자.
    static func sessionAbbrev(_ name: String) -> String {
      let n = name.trimmingCharacters(in: .whitespaces)
      if n.contains("스프린트") && n.contains("퀄리") { return "SQ" }
      if n.contains("스프린트") { return "SPR" }
      if n.contains("퀄리") { return "Q" }
      if n.contains("프랙티스") {
        if let digit = n.first(where: { $0.isNumber }) { return "FP\(digit)" }
        return "FP"
      }
      if n.contains("레이스") { return "RACE" }
      return String(n.prefix(4))
    }
  }
#endif
