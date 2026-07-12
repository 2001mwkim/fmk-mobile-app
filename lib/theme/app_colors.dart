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
  static const Color greenSoft = Color(0xFF4ADE80);

  /// FIA 플래그/세이프티카 상태 전용 의미 색상. 일반 강조 UI에는 사용하지 않는다.
  static const Color flagYellow = Color(0xFFFACC15);
  static const Color warningAmber = Color(0xFFF59E0B);
  // 웹 blue-400 (Tailwind) — blue 칩 텍스트
  static const Color blueSoft = Color(0xFF60A5FA);
  // 웹 mono 칩 텍스트 (slate-300)
  static const Color slate300 = Color(0xFFCBD5E1);

  // ── 보조 텍스트 계열 (웹 상세/목록 화면에서 그대로 옮긴 값) ──
  // 웹 #7880a0 — 라벨/메타 등 기본 보조 텍스트
  static const Color muted = Color(0xFF7880A0);
  // 웹 #aab0cc — 비활성/보조 이름 텍스트
  static const Color nameMuted = Color(0xFFAAB0CC);
  // 웹 #8088a8 — 히어로 서브 텍스트
  static const Color heroSub = Color(0xFF8088A8);
  // 웹 #5b6178 — 가장 흐린 텍스트(순위 컬럼 헤더 등). textEnded 와 같은 값.
  static const Color faint = textEnded;

  // ── 표면/구분선 계열 ──
  // 웹 #0e1018 — 카드 안 타일 표면
  static const Color tileSurface = Color(0xFF0E1018);
  // 웹 white/8 — 헤어라인 구분선
  static const Color hairline = Color(0x14FFFFFF);
  // 웹 white/7 — 칸 구분선
  static const Color divider = Color(0x12FFFFFF);
  // 웹 white/6 — 옅은 보더
  static const Color faintBorder = Color(0x0FFFFFFF);
  // 웹 white/5 — 행 구분선
  static const Color rowBorder = Color(0x0DFFFFFF);
  // black/20 — 패널 헤더 등 어두운 오버레이
  static const Color black20 = Color(0x33000000);

  // 일부 화면이 진한 배경(#090b12)을 참조할 때 쓰는 별칭.
  static const Color black = background;

  // ---- 홈 '최근 레이스 결과' 카드 (디자인 핸드오프 recent_race_result_card.html) ----
  // 카드보다 살짝 밝은 순위 행 타일 배경 (#1c2030)
  static const Color resultRowSurface = Color(0xFF1C2030);
  // 원형 chevron 버튼 배경 (#232838)
  static const Color resultChipSurface = Color(0xFF232838);
  // 2·3위 드라이버명 등 부드러운 본문 텍스트 (#e9eaf0)
  static const Color textSoft = Color(0xFFE9EAF0);

  // ---- 홈 리디자인 (디자인 핸드오프 home_screen_2a.html) — 히어로 일정 리스트 ----
  // 예정 세션 도트 (#3a4054)
  static const Color dotInactive = Color(0xFF3A4054);
  // 예정 세션 라벨 텍스트 (#c6c9d4)
  static const Color scheduleText = Color(0xFFC6C9D4);
}
