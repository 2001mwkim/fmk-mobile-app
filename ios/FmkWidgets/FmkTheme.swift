import SwiftUI
import UIKit

// 위젯 팔레트 — 시스템 외형(라이트/다크)을 자동으로 따라간다.
// 다크 값은 앱 팔레트(lib/theme/app_colors.dart)·Android 위젯
// (res/values-night/colors.xml)과 동일, 라이트 값은 Android
// res/values/colors.xml 과 동일하게 유지한다(양쪽 수동 동기화).
// 노란색 금지(P1 강조도 레드). 레드는 브랜드 일관성을 위해 양쪽 동일.
enum FmkTheme {
  static let bgTop = adaptive(light: 0xFFFFFFFF, dark: 0xFF171B2C)
  static let bgBottom = adaptive(light: 0xFFEEF0F6, dark: 0xFF0B0D16)
  /// 주 텍스트(이름 "white" 는 다크 기준 역할명 — 라이트에선 진한 네이비).
  static let white = adaptive(light: 0xFF11131C, dark: 0xFFFAFAFA)
  static let dim = adaptive(light: 0xFF6B7287, dark: 0xFFA1A1AA)
  static let text = adaptive(light: 0xFF3A3F52, dark: 0xFFD4D4D8)
  static let ghost = adaptive(light: 0xFFB5B9C8, dark: 0xFF52525B)
  static let red = adaptive(light: 0xFFEF4444, dark: 0xFFEF4444)
  /// 행 배경 레이어 — 다크는 흰색 4%, 라이트는 검정 4%.
  static let card = adaptive(light: 0x0A000000, dark: 0x0AFFFFFF)

  static var background: LinearGradient {
    LinearGradient(
      colors: [bgTop, bgBottom],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  /// 시스템 외형에 따라 해석되는 동적 색. 위젯·Live Activity 모두
  /// 렌더 시점의 colorScheme 환경으로 결정된다.
  private static func adaptive(light: UInt32, dark: UInt32) -> Color {
    Color(
      UIColor { traits in
        UIColor(argb: traits.userInterfaceStyle == .dark ? dark : light)
      })
  }
}

extension UIColor {
  convenience init(argb: UInt32) {
    self.init(
      red: CGFloat((argb >> 16) & 0xFF) / 255.0,
      green: CGFloat((argb >> 8) & 0xFF) / 255.0,
      blue: CGFloat(argb & 0xFF) / 255.0,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255.0
    )
  }
}

extension Color {
  /// ARGB 정수(0xAARRGGBB) → Color. 브리지가 저장한 Android 부호 있는
  /// 32bit 값(팀 컬러 등 — 양쪽 모드 공통)도 비트 패턴 그대로 받아들인다.
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

  /// 잠금화면(accessory) 위젯 배경 — 시스템이 비브런트/모노크롬으로 그리므로
  /// 자체 배경 없이 컨테이너 요구사항(iOS 17+)만 충족시킨다.
  @ViewBuilder
  func fmkAccessoryBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(for: .widget) { Color.clear }
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

  /// 다이나믹 아일랜드는 항상 검은 배경 — 라이트 모드에서도 다크 팔레트로
  /// 그리도록 colorScheme 을 고정한다.
  func fmkIslandScheme() -> some View {
    environment(\.colorScheme, .dark)
  }
}
