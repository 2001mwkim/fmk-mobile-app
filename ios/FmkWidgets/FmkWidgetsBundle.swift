import SwiftUI
import WidgetKit

// 위젯 kind 문자열('FmkHomeWidget' 등)은 앱 브리지의 updateWidget(iOSName:)
// 호출(lib/services/fmk_home_widget_bridge.dart)과 수동 동기화.
@main
struct FmkWidgetsBundle: WidgetBundle {
  var body: some Widget {
    FmkHomeWidget()
    FmkDriverStandingsWidget()
    FmkTeamStandingsWidget()
  }
}
