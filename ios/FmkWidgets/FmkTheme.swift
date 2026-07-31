import SwiftUI

// 색상 원본: android/app/src/main/res/values/colors.xml (웹 Tailwind 이식값).
// 앱 팔레트(lib/theme/app_colors.dart)와 같은 계열 — 새 hex 를 임의로 만들지
// 말고 Android 위젯과 동일 값을 유지한다. 노란색 금지(P1 강조도 레드).
enum FmkTheme {
  static let bgTop = Color(argb: 0xFF171B2C)
  static let bgBottom = Color(argb: 0xFF0B0D16)
  static let white = Color(argb: 0xFFFAFAFA)
  static let dim = Color(argb: 0xFFA1A1AA)
  static let text = Color(argb: 0xFFD4D4D8)
  static let ghost = Color(argb: 0xFF52525B)
  static let red = Color(argb: 0xFFEF4444)
  static let card = Color(argb: 0x0AFFFFFF)

  static var background: LinearGradient {
    LinearGradient(
      colors: [bgTop, bgBottom],
      startPoint: .top,
      endPoint: .bottom
    )
  }
}

extension Color {
  /// ARGB 정수(0xAARRGGBB) → Color. 브리지가 저장한 Android 부호 있는
  /// 32bit 값도 비트 패턴 그대로 받아들인다.
  init(argb: Int) {
    let value = UInt32(bitPattern: Int32(truncatingIfNeeded: argb))
    let alpha = Double((value >> 24) & 0xFF) / 255.0
    let red = Double((value >> 16) & 0xFF) / 255.0
    let green = Double((value >> 8) & 0xFF) / 255.0
    let blue = Double(value & 0xFF) / 255.0
    self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
  }
}

extension View {
  /// monospacedDigit 뷰 모디파이어는 iOS 15+ — 14 에서는 그대로 둔다
  /// (숫자 폭 정렬만 포기, 레이아웃은 동일).
  @ViewBuilder
  func fmkMonoDigits() -> some View {
    if #available(iOSApplicationExtension 15.0, *) {
      monospacedDigit()
    } else {
      self
    }
  }

  /// iOS 17+ 는 containerBackground 필수, 이전 버전은 일반 background.
  @ViewBuilder
  func fmkWidgetBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(for: .widget) { FmkTheme.background }
    } else {
      background(FmkTheme.background)
    }
  }
}
