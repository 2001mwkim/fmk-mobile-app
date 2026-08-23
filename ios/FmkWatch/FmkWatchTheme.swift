import SwiftUI

// 워치 팔레트 — 워치는 항상 검은 배경이라 다크 값만 쓴다(앱 팔레트
// lib/theme/app_colors.dart · iOS FmkTheme 다크 값과 동일). 노란색 금지.
// FmkTheme.swift 는 UIKit 동적 색(iOS 전용)을 써서 워치 타깃에 넣지 않고,
// 여기서 필요한 최소만 다시 정의한다(Color(argb:) 포함).
enum FmkWatchTheme {
  static let white = Color(argb: 0xFFFAFAFA)
  static let dim = Color(argb: 0xFFA1A1AA)
  static let text = Color(argb: 0xFFD4D4D8)
  static let ghost = Color(argb: 0xFF52525B)
  static let red = Color(argb: 0xFFEF4444)
  static let card = Color(argb: 0x14FFFFFF)
  static let bgTop = Color(argb: 0xFF171B2C)
  static let bgBottom = Color(argb: 0xFF0B0D16)
}

extension Color {
  /// Android/Dart 와 같은 ARGB 정수(음수 Int32 포함) → Color.
  init(argb: Int) {
    let value = UInt32(bitPattern: Int32(truncatingIfNeeded: argb))
    let alpha = Double((value >> 24) & 0xFF) / 255.0
    let red = Double((value >> 16) & 0xFF) / 255.0
    let green = Double((value >> 8) & 0xFF) / 255.0
    let blue = Double(value & 0xFF) / 255.0
    self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
  }
}

/// 다음 세션(하이라이트) 행 선택 — iOS FmkLockWidgetView.nextRow 와 동일 규칙.
func fmkNextSessionRow(payload: FmkPayload, at date: Date) -> FmkSessionRow? {
  let highlight = payload.highlightIndex(at: date)
  let index = (1...5).contains(highlight) && highlight <= payload.sessions.count
    ? highlight - 1 : 0
  return payload.sessions.indices.contains(index) ? payload.sessions[index] : nil
}

/// 다음 세션까지 남은 일수(당일 0). 정보 없으면 nil.
func fmkDaysLeft(to start: Date?, from date: Date) -> Int? {
  guard let start else { return nil }
  let days = Calendar.current.dateComponents(
    [.day], from: Calendar.current.startOfDay(for: date),
    to: Calendar.current.startOfDay(for: start)
  ).day
  return days.map { max($0, 0) }
}

/// 세션 창(시작 5분 전 ~ 종료 40분 후) — iOS FmkHomeProvider.inLiveWindow 와 동일.
func fmkInLiveWindow(payload: FmkPayload, now: Date) -> Bool {
  payload.sessions.contains { row in
    guard let start = row.start, let end = row.end else { return false }
    return now >= start.addingTimeInterval(-5 * 60) && now <= end.addingTimeInterval(40 * 60)
  }
}
