import SwiftUI
import WidgetKit

// 위젯 kind 문자열('FmkHomeWidget' 등)은 앱 브리지의 updateWidget(iOSName:)
// 호출(lib/services/fmk_home_widget_bridge.dart)과 수동 동기화.
@main
struct FmkWidgetsBundle: WidgetBundle {
  var body: some Widget {
    FmkHomeWidget()
    FmkScheduleWidget()
    FmkDriverStandingsWidget()
    FmkTeamStandingsWidget()
    FmkMyDriverWidget()
    FmkMyTeamWidget()
    liveActivities
  }

  // Live Activity 는 iOS 16.1+ — 익스텐션 최소 버전(15)보다 높아서
  // 가용성 분기로 조건부 포함한다(잠금화면·다이나믹 아일랜드).
  @WidgetBundleBuilder
  private var liveActivities: some Widget {
    if #available(iOSApplicationExtension 16.1, *) {
      FmkLiveActivityWidget()
    }
  }
}
