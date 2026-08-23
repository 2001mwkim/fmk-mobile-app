import SwiftUI
import WidgetKit

// 애플워치 컴플리케이션(워치 페이스·스마트 스택) 번들. watchOS 9+ 는
// 아이폰 위젯과 같은 WidgetKit 이라 FmkLive/FmkPayloadStore 를 공유한다.
// kind 문자열은 iOS 위젯과 겹치지 않게 FmkWatch* 접두사.
@main
struct FmkWatchWidgetsBundle: WidgetBundle {
  var body: some Widget {
    FmkWatchScheduleWidget()
    FmkWatchStandingsWidget()
    FmkWatchMyDriverWidget()
  }
}
