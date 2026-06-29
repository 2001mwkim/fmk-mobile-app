import 'package:flutter/material.dart';

/// 웹(fmk-f1-calendar)의 Tailwind 팔레트를 Flutter에서 재사용하기 위한 값.
/// 새 색을 임의로 만들지 않고, 웹에서 실제 사용 중인 값만 옮긴다.
class AppColors {
  const AppColors._();

  // 웹 body 배경 (globals.css --background: #090b12)
  static const Color background = Color(0xFF090B12);
  // 웹 공유 카드 표면 (Card.tsx bg-[#141828])
  static const Color card = Color(0xFF141828);
  // 웹 하단 네비 배경 (BottomNav.tsx bg-[#0c0e18])
  static const Color navSurface = Color(0xFF0C0E18);

  static const Color white = Color(0xFFFFFFFF);
  // 웹 neutral 칩 / 네비 비활성 텍스트 (#959bb6)
  static const Color textMuted = Color(0xFF959BB6);
  // 웹 ended 칩 텍스트 (#5b6178)
  static const Color textEnded = Color(0xFF5B6178);

  // 웹 border-white/10 (Card / BottomNav)
  static const Color border = Color(0x1AFFFFFF);

  // 웹 red-500 / red-400 (Tailwind)
  static const Color red = Color(0xFFEF4444);
  static const Color redSoft = Color(0xFFF87171);
  // 웹 blue-500 / blue-400 (Tailwind)
  static const Color blue = Color(0xFF3B82F6);
  static const Color blueSoft = Color(0xFF60A5FA);
  // 웹 mono 칩 텍스트 (slate-300)
  static const Color slate300 = Color(0xFFCBD5E1);

  // 기존 화면이 참조하던 이름 유지 (구조 변경 없이 웹 팔레트로 매핑)
  static const Color black = background;
  static const Color surface = card;
  static const Color surfaceHigh = card;
}
