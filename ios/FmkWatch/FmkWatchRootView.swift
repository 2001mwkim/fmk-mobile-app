import SwiftUI

// 워치 앱 화면 — 좌우 스와이프 4페이지(일정 / 라이브·결과 / 순위 / MY).
// 데이터는 모두 아이폰이 밀어준 페이로드(FmkPayload)라 네트워크는
// 라이브 페이지의 세션 창 fetch 뿐이다.
struct FmkWatchRootView: View {
  @ObservedObject private var bridge = FmkWatchSessionBridge.shared

  var body: some View {
    // lastReceived 가 바뀔 때마다 id 가 바뀌어 페이로드를 다시 읽는다.
    Group {
      if bridge.hasData {
        TabView {
          FmkWatchScheduleView()
          FmkWatchLiveView()
          FmkWatchStandingsView()
          FmkWatchMyPicksView()
        }
        .tabViewStyle(.page)
      } else {
        FmkWatchEmptyView()
      }
    }
    .id(bridge.lastReceived)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
      LinearGradient(
        colors: [FmkWatchTheme.bgTop, FmkWatchTheme.bgBottom],
        startPoint: .top, endPoint: .bottom
      ).ignoresSafeArea())
  }
}

struct FmkWatchEmptyView: View {
  var body: some View {
    VStack(spacing: 6) {
      Text("비아 포뮬러").font(.system(size: 15, weight: .heavy))
        .foregroundColor(FmkWatchTheme.white)
      Text("아이폰에서 앱을 한 번 열면\n일정·순위가 워치로 전달됩니다.")
        .font(.system(size: 12)).multilineTextAlignment(.center)
        .foregroundColor(FmkWatchTheme.dim)
    }
    .padding()
  }
}

// ── 일정 ──
struct FmkWatchScheduleView: View {
  private let payload = FmkPayload.load()
  private let now = Date()

  var body: some View {
    let nextId = fmkNextSessionRow(payload: payload, at: now)?.id
    ScrollView {
      VStack(alignment: .leading, spacing: 4) {
        Text("\(payload.scheduleGpFlag) \(payload.scheduleGpName)")
          .font(.system(size: 13, weight: .heavy)).foregroundColor(FmkWatchTheme.white)
          .lineLimit(2).minimumScaleFactor(0.8)
        ForEach(Array(payload.sessions.enumerated()), id: \.offset) { _, row in
          let isNext = row.id == nextId
          HStack(spacing: 4) {
            Rectangle().fill(isNext ? FmkWatchTheme.red : FmkWatchTheme.ghost)
              .frame(width: 2)
            Text(row.name).font(.system(size: 12, weight: isNext ? .heavy : .semibold))
              .foregroundColor(isNext ? FmkWatchTheme.white : FmkWatchTheme.text)
              .lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 2)
            Text(row.date).font(.system(size: 11)).foregroundColor(FmkWatchTheme.dim)
            Text(row.time).font(.system(size: 12, weight: .semibold)).monospacedDigit()
              .foregroundColor(isNext ? FmkWatchTheme.white : FmkWatchTheme.text)
          }
          .padding(.vertical, 3).padding(.horizontal, 5)
          .background(isNext ? FmkWatchTheme.card : Color.clear)
          .cornerRadius(6)
        }
        Text("한국시간(KST)").font(.system(size: 9)).foregroundColor(FmkWatchTheme.ghost)
      }
      .padding(.horizontal, 4)
    }
    .navigationTitle("일정")
  }
}

// ── 라이브 · 결과 ──
struct FmkWatchLiveView: View {
  private let payload = FmkPayload.load()
  @State private var live: FmkLiveState?
  @State private var loading = false
  private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 4) {
        if let state = live ?? payload.storedResultState {
          HStack(spacing: 4) {
            Text(state.badgeText)
              .font(.system(size: 10, weight: .heavy)).foregroundColor(.white)
              .padding(.horizontal, 5).padding(.vertical, 2)
              .background(state.isLive ? FmkWatchTheme.red : FmkWatchTheme.ghost)
              .cornerRadius(4)
            if state.isLive && state.lapTotal > 0 {
              Text("LAP \(state.lapCurrent)/\(state.lapTotal)")
                .font(.system(size: 10, weight: .semibold)).monospacedDigit()
                .foregroundColor(FmkWatchTheme.dim)
            }
          }
          Text(state.gpName).font(.system(size: 12, weight: .heavy))
            .foregroundColor(FmkWatchTheme.white).lineLimit(1).minimumScaleFactor(0.7)
          ForEach(state.rows) { row in
            HStack(spacing: 4) {
              Text("P\(row.position)").font(.system(size: 11, weight: .heavy))
                .foregroundColor(row.position == 1 ? FmkWatchTheme.red : FmkWatchTheme.dim)
                .frame(width: 22, alignment: .leading)
              Rectangle().fill(Color(argb: row.colorArgb)).frame(width: 2, height: 14)
              Text(row.name).font(.system(size: 12, weight: .semibold))
                .foregroundColor(FmkWatchTheme.white).lineLimit(1).minimumScaleFactor(0.7)
              Spacer(minLength: 2)
              Text(row.time).font(.system(size: 11)).monospacedDigit()
                .foregroundColor(FmkWatchTheme.text)
            }
            .padding(.vertical, 2)
          }
        } else if loading {
          ProgressView().tint(FmkWatchTheme.red)
        } else {
          Text("진행 중인 세션이 없습니다").font(.system(size: 12))
            .foregroundColor(FmkWatchTheme.dim)
          if let next = fmkNextSessionRow(payload: payload, at: Date()) {
            Text("다음: \(next.name) \(next.date) \(next.time)")
              .font(.system(size: 11)).foregroundColor(FmkWatchTheme.text)
          }
        }
      }
      .padding(.horizontal, 4)
    }
    .navigationTitle("라이브")
    .task { await refresh() }
    .onReceive(timer) { _ in Task { await refresh() } }
  }

  /// 세션 창에서만 live.json 을 직접 가져온다(아이폰 위젯과 동일 정책).
  private func refresh() async {
    let now = Date()
    guard fmkInLiveWindow(payload: payload, now: now) else { live = nil; return }
    if live == nil { loading = true }
    if let snapshot = await FmkLive.fetch(payload: payload) {
      live = FmkLive.displayState(snapshot: snapshot, payload: payload, now: now)
    }
    loading = false
  }
}

// ── 순위 ──
struct FmkWatchStandingsView: View {
  @State private var showTeams = false
  private let drivers = FmkPayload.standings(prefix: "stDriver")
  private let teams = FmkPayload.standings(prefix: "stTeam")

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 4) {
        // watchOS 에는 segmented 피커가 없어 탭 가능한 2버튼 토글로 대신한다.
        HStack(spacing: 4) {
          toggleButton("드라이버", selected: !showTeams) { showTeams = false }
          toggleButton("팀", selected: showTeams) { showTeams = true }
        }
        let rows = showTeams ? teams : drivers
        if rows.isEmpty {
          Text("순위 데이터 없음").font(.system(size: 12)).foregroundColor(FmkWatchTheme.dim)
        }
        ForEach(rows) { row in
          HStack(spacing: 4) {
            Text("\(row.position)").font(.system(size: 12, weight: .heavy)).monospacedDigit()
              .foregroundColor(row.position == 1 ? FmkWatchTheme.red : FmkWatchTheme.dim)
              .frame(width: 16, alignment: .trailing)
            Rectangle().fill(Color(argb: row.teamColorArgb)).frame(width: 2, height: 14)
            Text(row.name).font(.system(size: 12, weight: .semibold))
              .foregroundColor(FmkWatchTheme.white).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 2)
            if !row.changeLabel.isEmpty {
              Text(row.changeLabel).font(.system(size: 9, weight: .bold))
                .foregroundColor(Color(argb: row.changeColorArgb))
            }
            Text(row.points).font(.system(size: 11, weight: .semibold)).monospacedDigit()
              .foregroundColor(FmkWatchTheme.text)
          }
          .padding(.vertical, 2)
        }
      }
      .padding(.horizontal, 4)
    }
    .navigationTitle("순위")
  }

  private func toggleButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title).font(.system(size: 11, weight: .heavy))
        .foregroundColor(selected ? .white : FmkWatchTheme.dim)
        .frame(maxWidth: .infinity).padding(.vertical, 4)
        .background(selected ? FmkWatchTheme.red : FmkWatchTheme.card)
        .cornerRadius(6)
    }
    .buttonStyle(.plain)
  }
}

// ── MY PICKS ──
struct FmkWatchMyPicksView: View {
  private let driver = FmkPayload.myDriver()
  private let team = FmkPayload.myTeam()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 6) {
        card(
          title: "MY DRIVER", isSet: driver.isSet && driver.found,
          name: driver.isSet ? driver.code : "미설정",
          sub: driver.isSet ? driver.nameEn : "아이폰 설정에서 선택",
          position: driver.position, points: driver.points, gap: driver.gap,
          change: driver.changeLabel, changeColor: driver.changeColorArgb,
          color: driver.colorArgb)
        card(
          title: "MY TEAM", isSet: team.isSet && team.found,
          name: team.isSet ? team.teamEn : "미설정",
          sub: team.isSet
            ? team.drivers.map { "\($0.code) P\($0.position)" }.joined(separator: " · ")
            : "아이폰 설정에서 선택",
          position: team.position, points: team.points, gap: team.gap,
          change: team.changeLabel, changeColor: team.changeColorArgb,
          color: team.colorArgb)
      }
      .padding(.horizontal, 4)
    }
    .navigationTitle("MY")
  }

  @ViewBuilder
  private func card(
    title: String, isSet: Bool, name: String, sub: String, position: Int,
    points: String, gap: String, change: String, changeColor: Int, color: Int
  ) -> some View {
    HStack(spacing: 6) {
      Rectangle().fill(isSet ? Color(argb: color) : FmkWatchTheme.ghost).frame(width: 3)
      VStack(alignment: .leading, spacing: 1) {
        Text(title).font(.system(size: 9, weight: .heavy)).foregroundColor(FmkWatchTheme.dim)
        HStack(spacing: 4) {
          Text(name).font(.system(size: 14, weight: .heavy)).foregroundColor(FmkWatchTheme.white)
            .lineLimit(1).minimumScaleFactor(0.7)
          if isSet {
            Text("P\(position)").font(.system(size: 12, weight: .heavy))
              .foregroundColor(position == 1 ? FmkWatchTheme.red : FmkWatchTheme.text)
            if !change.isEmpty {
              Text(change).font(.system(size: 9, weight: .bold))
                .foregroundColor(Color(argb: changeColor))
            }
          }
        }
        Text(sub).font(.system(size: 10)).foregroundColor(FmkWatchTheme.dim)
          .lineLimit(1).minimumScaleFactor(0.7)
        if isSet {
          Text("\(points) pts" + (gap.isEmpty ? "" : " · \(gap)"))
            .font(.system(size: 10, weight: .semibold)).monospacedDigit()
            .foregroundColor(FmkWatchTheme.text)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(6)
    .background(FmkWatchTheme.card).cornerRadius(8)
  }
}
