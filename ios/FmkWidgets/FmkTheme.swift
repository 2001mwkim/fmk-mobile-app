import SwiftUI
import UIKit

// 위젯 팔레트 — 앱 설정(설정 › 위젯 테마: 다크/라이트/시스템)을 따른다.
// 기본은 다크(앱이 다크 브랜드). system 이면 기기 외형을 자동으로 따라간다.
// 선택값은 브리지가 App Group 'widgetThemeMode' 키로 저장(Android
// FmkWidgetTheme.kt 와 동일 키/값)하고, 아래 pick() 이 모드에 맞는 색을 돌려준다.
// 다크 값은 앱 팔레트(lib/theme/app_colors.dart)·Android 위젯
// (res/values-night/colors.xml)과 동일, 라이트 값은 Android
// res/values/colors.xml 과 동일하게 유지한다(양쪽 수동 동기화).
// 노란색 금지(P1 강조도 레드). 레드는 브랜드 일관성을 위해 양쪽 동일.
enum FmkTheme {
  // ── 홈 화면 위젯 팔레트 — 앱 설정(위젯 테마)을 반영한다 ──
  // dark/light 는 고정 색, system 은 렌더 환경의 라이트/다크를 따르는 동적 색.
  // (environment(\.colorScheme) 강제는 containerBackground 와 텍스트가 서로 다른
  //  trait 로 풀리는 경우가 있어 쓰지 않고, 색 자체를 모드로 확정한다.)
  static var bgTop: Color { pick(light: 0xFFFFFFFF, dark: 0xFF171B2C) }
  static var bgBottom: Color { pick(light: 0xFFEEF0F6, dark: 0xFF0B0D16) }
  /// 주 텍스트(이름 "white" 는 다크 기준 역할명 — 라이트에선 진한 네이비).
  static var white: Color { pick(light: 0xFF11131C, dark: 0xFFFAFAFA) }
  static var dim: Color { pick(light: 0xFF6B7287, dark: 0xFFA1A1AA) }
  static var text: Color { pick(light: 0xFF3A3F52, dark: 0xFFD4D4D8) }
  static var ghost: Color { pick(light: 0xFFB5B9C8, dark: 0xFF52525B) }
  static var red: Color { pick(light: 0xFFEF4444, dark: 0xFFEF4444) }
  /// 행 배경 레이어 — 다크는 흰색 4%, 라이트는 검정 4%.
  static var card: Color { pick(light: 0x0A000000, dark: 0x0AFFFFFF) }

  static var background: LinearGradient {
    LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)
  }

  /// 위젯 테마 모드에 따라 고정 색 또는 시스템 동적 색을 고른다.
  private static func pick(light: UInt32, dark: UInt32) -> Color {
    switch FmkWidgetThemeMode.load() {
    case .dark: return Color(argb: Int(dark))
    case .light: return Color(argb: Int(light))
    case .system: return adaptive(light: light, dark: dark)
    }
  }

  // ── Live Activity 팔레트 — 항상 시스템 외형을 따른다(위젯 테마 설정과 무관).
  //    잠금화면 LA 배경은 시스템이 정하고, 다이나믹 아일랜드는 fmkIslandScheme()
  //    으로 다크 고정이라 여기엔 동적 색이 맞다.
  enum system {
    static let bgTop = adaptive(light: 0xFFFFFFFF, dark: 0xFF171B2C)
    static let bgBottom = adaptive(light: 0xFFEEF0F6, dark: 0xFF0B0D16)
    static let white = adaptive(light: 0xFF11131C, dark: 0xFFFAFAFA)
    static let dim = adaptive(light: 0xFF6B7287, dark: 0xFFA1A1AA)
    static let text = adaptive(light: 0xFF3A3F52, dark: 0xFFD4D4D8)
    static let ghost = adaptive(light: 0xFFB5B9C8, dark: 0xFF52525B)
    static let red = adaptive(light: 0xFFEF4444, dark: 0xFFEF4444)
    static let card = adaptive(light: 0x0A000000, dark: 0x0AFFFFFF)
    static var background: LinearGradient {
      LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)
    }
  }

  /// 시스템 외형에 따라 해석되는 동적 색 — 렌더 시점의 colorScheme 환경으로 결정된다.
  fileprivate static func adaptive(light: UInt32, dark: UInt32) -> Color {
    Color(
      UIColor { traits in
        UIColor(argb: traits.userInterfaceStyle == .dark ? dark : light)
      })
  }
}

/// 앱 설정의 위젯 테마 모드(브리지 'widgetThemeMode': dark/light/system).
enum FmkWidgetThemeMode {
  case dark, light, system

  static func load() -> FmkWidgetThemeMode {
    switch UserDefaults(suiteName: fmkAppGroupId)?.string(forKey: "widgetThemeMode") {
    case "light": return .light
    case "system": return .system
    default: return .dark  // 미저장 포함 — Dart WidgetThemeMode.fromStorage 와 동일
    }
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
