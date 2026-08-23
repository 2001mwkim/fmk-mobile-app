import SwiftUI

// 워치 팔레트 — 워치는 항상 검은 배경이라 다크 값만 쓴다(앱 팔레트
// lib/theme/app_colors.dart · iOS FmkTheme 다크 값과 동일). 노란색 금지.
// FmkTheme.swift 는 UIKit 동적 색(iOS 전용)을 써서 워치 타깃에 넣지 않고,
// 여기서 필요한 최소만 다시 정의한다(Color(argb:) 포함).
enum FmkWatchTheme {
  static let white = c(0xFFFAFAFA)
  static let dim = c(0xFFA1A1AA)
  static let text = c(0xFFD4D4D8)
  static let ghost = c(0xFF52525B)
  static let red = c(0xFFEF4444)
  static let card = c(0x14FFFFFF)
  static let bgTop = c(0xFF171B2C)
  static let bgBottom = c(0xFF0B0D16)

  /// ARGB 리터럴 → Color. 워치 실기기(arm64_32)는 Int 가 32비트라 0xFF… 리터럴이
  /// Int 로 바로 못 들어가므로 UInt32 로 받아 비트 그대로 옮긴다.
  private static func c(_ argb: UInt32) -> Color { Color(argb: Int(Int32(bitPattern: argb))) }
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

/// 드라이버 TLA — 행에 code 가 있으면 그대로, 없으면 한글 이름으로 역조회
/// (브리지 driverNamesKoJson: code → 한글 이름). 못 찾으면 이름 앞 3글자.
func fmkDriverCode(name: String, code: String = "", payload: FmkPayload) -> String {
  if !code.isEmpty { return code.uppercased() }
  let trimmed = name.trimmingCharacters(in: .whitespaces)
  if let hit = payload.driverNamesKo.first(where: { $0.value == trimmed }) {
    return hit.key.uppercased()
  }
  return String(trimmed.prefix(3)).uppercased()
}
