import 'package:flutter/material.dart';

/// 앱 테마 식별자. 저장 문자열·설정 UI 라벨은
/// services/app_theme_controller.dart 가 담당한다.
/// - dark: 기존 기본 디자인(블루톤 다크 + 레드 라인) — 값은 웹 Tailwind 원본 그대로
/// - light: 흰 배경 + 레드 라인
/// - fmk: 포뮬러 매거진 코리아 브랜드(검정 배경 + 옐로 라인)
enum AppThemeId { dark, light, fmk }

/// 테마별 색 묶음. AppColors 의 getter 가 현재 선택된 팔레트를 읽는다.
/// 새 토큰을 추가하면 세 팔레트 모두에 값을 정의할 것(컴파일러가 강제한다).
class AppPalette {
  const AppPalette({
    required this.id,
    required this.brightness,
    required this.background,
    required this.card,
    required this.navSurface,
    required this.textPrimary,
    required this.onAccent,
    required this.textMuted,
    required this.textEnded,
    required this.border,
    required this.red,
    required this.redSoft,
    required this.greenSoft,
    required this.blueSoft,
    required this.orangeSoft,
    required this.slate400,
    required this.slate300,
    required this.muted,
    required this.nameMuted,
    required this.heroSub,
    required this.tileSurface,
    required this.hairline,
    required this.divider,
    required this.faintBorder,
    required this.rowBorder,
    required this.black20,
    required this.resultRowSurface,
    required this.resultChipSurface,
    required this.textSoft,
    required this.dotInactive,
    required this.scheduleText,
    required this.heroAccent,
    required this.heroAccentBright,
    required this.heroGradTop,
    required this.heroGradMid,
    required this.heroGradBottom,
    required this.heroMeta,
    required this.heroSubText,
    required this.heroDim,
    required this.heroRowText,
    required this.heroDotIdle,
    required this.panelSurface,
    required this.heroListSurface,
    required this.metallic,
    required this.circuitBand,
    required this.circuitLabel,
    required this.scrimPill,
    required this.scrimPillText,
    required this.controlSurface,
    required this.tyreSoftLabel,
    required this.tyreMediumLabel,
    required this.tyreHardLabel,
  });

  final AppThemeId id;
  final Brightness brightness;

  final Color background;
  final Color card;
  final Color navSurface;

  /// 다크 계열에선 흰색, 라이트에선 진한 잉크색 — "본문 대비 최상위 텍스트".
  final Color textPrimary;

  /// 액센트 단색 위에 얹는 텍스트/아이콘(FMK 옐로 위엔 검정이어야 읽힌다).
  final Color onAccent;
  final Color textMuted;
  final Color textEnded;
  final Color border;

  /// 브랜드 액센트. dark/light 는 레드, fmk 는 옐로.
  final Color red;
  final Color redSoft;
  final Color greenSoft;
  final Color blueSoft;
  final Color orangeSoft;
  final Color slate400;
  final Color slate300;

  final Color muted;
  final Color nameMuted;
  final Color heroSub;

  final Color tileSurface;
  final Color hairline;
  final Color divider;
  final Color faintBorder;
  final Color rowBorder;
  final Color black20;

  final Color resultRowSurface;
  final Color resultChipSurface;
  final Color textSoft;

  final Color dotInactive;
  final Color scheduleText;

  final Color heroAccent;
  final Color heroAccentBright;
  final Color heroGradTop;
  final Color heroGradMid;
  final Color heroGradBottom;
  final Color heroMeta;
  final Color heroSubText;
  final Color heroDim;
  final Color heroRowText;
  final Color heroDotIdle;

  /// 순위 패널 표면(다크에선 레드 틴트, FMK 에선 옐로 틴트).
  final Color panelSurface;

  /// 홈 히어로 카드 안 세션 리스트 컨테이너(다크에선 black/25 오버레이,
  /// 라이트에선 반투명 화이트 — 밝은 그라데이션 위 검정 오버레이는 탁해진다).
  final Color heroListSurface;

  /// 드라이버 코드(TLA) 등 메탈릭 톤 강조 텍스트.
  final Color metallic;

  /// 트랙맵 플레이스홀더 대각선 밴드 / 라벨.
  final Color circuitBand;
  final Color circuitLabel;

  /// 트랙맵 위 ROUND 필(배경/텍스트). 다크 계열은 검정 스크림+슬레이트,
  /// 라이트는 흰 필+잉크 — 흰 카드 위 검정 스크림은 글자가 묻힌다.
  final Color scrimPill;
  final Color scrimPillText;

  /// 라이브 센터의 컨트롤 표면(LAP 칩, LAP/SECTOR/TIRE 탭 트랙,
  /// '4위 이하 순위 보기' 확장 바). 다크 계열은 black/20 침강 표면,
  /// 라이트는 흰색 — 회색 침강 표면이 라이트에선 탁해 보인다.
  final Color controlSurface;

  /// 타이어 컴파운드 이름 라벨(원판 아래 텍스트). 링 색(tyreMedium 옐로,
  /// tyreHard 화이트)은 흰 배경에서 안 읽혀 라이트만 진한 변형을 쓴다.
  final Color tyreSoftLabel;
  final Color tyreMediumLabel;
  final Color tyreHardLabel;

  /// 기존 기본 디자인 — 웹(fmk-f1-calendar) Tailwind 원본값 그대로.
  /// 이 팔레트의 값은 비트 단위로 종전 AppColors 상수와 동일해야 한다
  /// (테마 도입으로 인한 기존 디자인 회귀 방지).
  static const AppPalette dark = AppPalette(
    id: AppThemeId.dark,
    brightness: Brightness.dark,
    // 웹 body 배경 (globals.css --background: #090b12)
    background: Color(0xFF090B12),
    // 웹 공유 카드 표면 (Card.tsx bg-[#141828])
    card: Color(0xFF141828),
    // 웹 하단 네비 배경 (BottomNav.tsx bg-[#0c0e18])
    navSurface: Color(0xFF0C0E18),
    textPrimary: Color(0xFFFFFFFF),
    onAccent: Color(0xFFFFFFFF),
    // 웹 neutral 칩 / 네비 비활성 텍스트 (#959bb6)
    textMuted: Color(0xFF959BB6),
    // 웹 ended 칩 텍스트 (#5b6178)
    textEnded: Color(0xFF5B6178),
    // 웹 border-white/10 (Card / BottomNav)
    border: Color(0x1AFFFFFF),
    // 웹 red-500 / red-400 (Tailwind)
    red: Color(0xFFEF4444),
    redSoft: Color(0xFFF87171),
    greenSoft: Color(0xFF4ADE80),
    // 웹 blue-400 (Tailwind) — blue 칩 텍스트
    blueSoft: Color(0xFF60A5FA),
    // 순위 변동 칩 등 orange-400 (Tailwind)
    orangeSoft: Color(0xFFFB923C),
    // 중립 칩 배경 원색 slate-400 (Tailwind)
    slate400: Color(0xFF94A3B8),
    // 웹 mono 칩 텍스트 (slate-300)
    slate300: Color(0xFFCBD5E1),
    // 웹 #7880a0 — 라벨/메타 등 기본 보조 텍스트
    muted: Color(0xFF7880A0),
    // 웹 #aab0cc — 비활성/보조 이름 텍스트
    nameMuted: Color(0xFFAAB0CC),
    // 웹 #8088a8 — 히어로 서브 텍스트
    heroSub: Color(0xFF8088A8),
    // 웹 #0e1018 — 카드 안 타일 표면
    tileSurface: Color(0xFF0E1018),
    // 웹 white/8 — 헤어라인 구분선
    hairline: Color(0x14FFFFFF),
    // 웹 white/7 — 칸 구분선
    divider: Color(0x12FFFFFF),
    // 웹 white/6 — 옅은 보더
    faintBorder: Color(0x0FFFFFFF),
    // 웹 white/5 — 행 구분선
    rowBorder: Color(0x0DFFFFFF),
    // black/20 — 패널 헤더 등 어두운 오버레이
    black20: Color(0x33000000),
    // 홈 '최근 레이스 결과' 카드 (디자인 핸드오프 recent_race_result_card.html)
    resultRowSurface: Color(0xFF1C2030),
    resultChipSurface: Color(0xFF232838),
    textSoft: Color(0xFFE9EAF0),
    // 홈 리디자인 (home_screen_2a.html) — 히어로 일정 리스트
    dotInactive: Color(0xFF3A4054),
    scheduleText: Color(0xFFC6C9D4),
    // 히어로 v2 (Home v2.dc.html 1a) — 기존 red 보다 살짝 웜톤
    heroAccent: Color(0xFFF25C5C),
    heroAccentBright: Color(0xFFF58A8A),
    heroGradTop: Color(0xFF221018),
    heroGradMid: Color(0xFF16121C),
    heroGradBottom: Color(0xFF121218),
    heroMeta: Color(0xFF8B8B99),
    heroSubText: Color(0xFF9A9AA8),
    heroDim: Color(0xFF6E6E7C),
    heroRowText: Color(0xFFA8A8B6),
    heroDotIdle: Color(0xFF3A3A46),
    panelSurface: Color(0xFF141019),
    heroListSurface: Color(0x40000000),
    metallic: Color(0xFFE8EDF6),
    circuitBand: Color(0xFF12141E),
    circuitLabel: Color(0xFF6B7090),
    scrimPill: Color(0x80000000),
    scrimPillText: Color(0xFFCBD5E1),
    controlSurface: Color(0x33000000),
    tyreSoftLabel: Color(0xFFF87171),
    tyreMediumLabel: Color(0xFFFFD12E),
    tyreHardLabel: Color(0xFFF4F4F6),
  );

  /// 라이트 — 흰 배경 + 레드 라인. 다크의 white-alpha 구분선은 black-alpha 로,
  /// 레드는 흰 배경 대비를 위해 red-600 계열로 반 단계 낮춘다.
  static const AppPalette light = AppPalette(
    id: AppThemeId.light,
    brightness: Brightness.light,
    background: Color(0xFFF6F7FA),
    card: Color(0xFFFFFFFF),
    navSurface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF14161F),
    onAccent: Color(0xFFFFFFFF),
    textMuted: Color(0xFF5C6274),
    textEnded: Color(0xFF9BA0B0),
    border: Color(0x14000000),
    // red-600 — 흰 배경에서 red-500 보다 대비가 좋다
    red: Color(0xFFDC2626),
    redSoft: Color(0xFFEF4444),
    greenSoft: Color(0xFF16A34A),
    blueSoft: Color(0xFF2563EB),
    orangeSoft: Color(0xFFEA580C),
    slate400: Color(0xFF64748B),
    slate300: Color(0xFF475569),
    muted: Color(0xFF6A7086),
    nameMuted: Color(0xFF565C70),
    heroSub: Color(0xFF6E7488),
    tileSurface: Color(0xFFF1F2F7),
    hairline: Color(0x10000000),
    divider: Color(0x0E000000),
    faintBorder: Color(0x0C000000),
    rowBorder: Color(0x0A000000),
    black20: Color(0x14000000),
    resultRowSurface: Color(0xFFF2F3F8),
    resultChipSurface: Color(0xFFE9EBF2),
    textSoft: Color(0xFF2B2E3A),
    dotInactive: Color(0xFFC8CCDA),
    scheduleText: Color(0xFF3F4457),
    heroAccent: Color(0xFFE04848),
    heroAccentBright: Color(0xFFD13F3F),
    heroGradTop: Color(0xFFFFF1EF),
    heroGradMid: Color(0xFFFAF4F6),
    heroGradBottom: Color(0xFFF6F6FA),
    heroMeta: Color(0xFF787886),
    heroSubText: Color(0xFF6C6C7C),
    heroDim: Color(0xFF9698A6),
    heroRowText: Color(0xFF4C4C5A),
    heroDotIdle: Color(0xFFD4D4DE),
    panelSurface: Color(0xFFFBF3F3),
    heroListSurface: Color(0x9EFFFFFF),
    metallic: Color(0xFF3D4350),
    circuitBand: Color(0xFFE9EBF3),
    circuitLabel: Color(0xFF8A90A8),
    scrimPill: Color(0xD9FFFFFF),
    scrimPillText: Color(0xFF3F4457),
    controlSurface: Color(0xFFFFFFFF),
    // 라이트 전용 진한 변형: 레드 그대로, 옐로는 yellow-700, 화이트는 slate-500
    tyreSoftLabel: Color(0xFFDC2626),
    tyreMediumLabel: Color(0xFFA16207),
    tyreHardLabel: Color(0xFF64748B),
  );

  /// FMK — 포뮬러 매거진 코리아 브랜드(검정 배경 + 옐로 라인).
  /// 블루 틴트 회색 대신 무채색 회색을 쓴다(순검정 배경 위 톤 정합).
  /// 옐로 위 텍스트는 반드시 onAccent(검정)를 쓸 것.
  static const AppPalette fmk = AppPalette(
    id: AppThemeId.fmk,
    brightness: Brightness.dark,
    background: Color(0xFF000000),
    card: Color(0xFF111111),
    navSurface: Color(0xFF0A0A0A),
    textPrimary: Color(0xFFFFFFFF),
    onAccent: Color(0xFF000000),
    textMuted: Color(0xFFA3A3A8),
    textEnded: Color(0xFF62626A),
    border: Color(0x1AFFFFFF),
    // FMK 브랜드 옐로 — 액센트 계열만 옐로로 치환한다
    red: Color(0xFFFFD200),
    redSoft: Color(0xFFFFDF66),
    greenSoft: Color(0xFF4ADE80),
    blueSoft: Color(0xFF60A5FA),
    orangeSoft: Color(0xFFFB923C),
    slate400: Color(0xFF94A3B8),
    slate300: Color(0xFFCBD5E1),
    muted: Color(0xFF8A8A92),
    nameMuted: Color(0xFFB4B4BC),
    heroSub: Color(0xFF90909A),
    tileSurface: Color(0xFF0C0C0E),
    hairline: Color(0x14FFFFFF),
    divider: Color(0x12FFFFFF),
    faintBorder: Color(0x0FFFFFFF),
    rowBorder: Color(0x0DFFFFFF),
    black20: Color(0x33000000),
    resultRowSurface: Color(0xFF1B1B1E),
    resultChipSurface: Color(0xFF242428),
    textSoft: Color(0xFFECECEF),
    dotInactive: Color(0xFF3C3C42),
    scheduleText: Color(0xFFCACACF),
    heroAccent: Color(0xFFFFD200),
    heroAccentBright: Color(0xFFFFE566),
    heroGradTop: Color(0xFF1F1B08),
    heroGradMid: Color(0xFF17150C),
    heroGradBottom: Color(0xFF111110),
    heroMeta: Color(0xFF8E8E96),
    heroSubText: Color(0xFF9C9CA4),
    heroDim: Color(0xFF6E6E76),
    heroRowText: Color(0xFFACACB4),
    heroDotIdle: Color(0xFF3A3A40),
    panelSurface: Color(0xFF171408),
    heroListSurface: Color(0x40000000),
    metallic: Color(0xFFE8EDF6),
    circuitBand: Color(0xFF101010),
    circuitLabel: Color(0xFF6E6E78),
    scrimPill: Color(0x80000000),
    scrimPillText: Color(0xFFCBD5E1),
    controlSurface: Color(0x33000000),
    tyreSoftLabel: Color(0xFFF87171),
    tyreMediumLabel: Color(0xFFFFD12E),
    tyreHardLabel: Color(0xFFF4F4F6),
  );

  static AppPalette of(AppThemeId id) {
    switch (id) {
      case AppThemeId.dark:
        return dark;
      case AppThemeId.light:
        return light;
      case AppThemeId.fmk:
        return fmk;
    }
  }
}

/// 웹(fmk-f1-calendar)의 Tailwind 팔레트를 Flutter에서 재사용하기 위한 값.
/// 2026-08 앱 테마 도입으로 static const → 현재 팔레트를 읽는 getter 가 됐다.
/// 호출부 이름은 그대로 유지한다(452곳 무수정). 새 hex 리터럴을 화면에 직접
/// 넣지 말고 여기(팔레트)에 토큰을 추가할 것.
///
/// 테마와 무관한 의미색(semantic)만 여전히 const 다: 타이어 컴파운드,
/// FIA 플래그, 날씨 지표, 타이밍 퍼플.
class AppColors {
  const AppColors._();

  /// 현재 팔레트. 교체는 AppThemeController 만 한다(교체 후 앱 루트 리빌드).
  static AppPalette palette = AppPalette.dark;

  static AppThemeId get themeId => palette.id;
  static Brightness get brightness => palette.brightness;

  static Color get background => palette.background;
  static Color get card => palette.card;
  static Color get navSurface => palette.navSurface;

  /// 최상위 대비 텍스트(다크에선 흰색, 라이트에선 잉크색).
  /// "진짜 흰색"이 필요하면 pureWhite 를 쓸 것.
  static Color get white => palette.textPrimary;
  static const Color pureWhite = Color(0xFFFFFFFF);

  /// 액센트 단색 배경 위 텍스트/아이콘(FMK 옐로 위엔 검정).
  static Color get onAccent => palette.onAccent;

  static Color get textMuted => palette.textMuted;
  static Color get textEnded => palette.textEnded;
  static Color get border => palette.border;

  static Color get red => palette.red;
  static Color get redSoft => palette.redSoft;
  static Color get greenSoft => palette.greenSoft;
  static Color get blueSoft => palette.blueSoft;
  static Color get orangeSoft => palette.orangeSoft;
  static Color get slate400 => palette.slate400;
  static Color get slate300 => palette.slate300;

  // 타이어 컴파운드 마킹색(피렐리 실물: 소프트=레드, 미디엄=옐로, 하드=화이트).
  // 실물 의미색이므로 테마와 무관하게 고정 — 일반 UI 강조에는 쓰지 말 것.
  static const Color tyreSoft = Color(0xFFF87171);
  static const Color tyreMedium = Color(0xFFFFD12E);
  static const Color tyreHard = Color(0xFFF4F4F6);

  // Live Center weather metrics. Each metric keeps a stable accent so it can
  // be recognized at a glance without relying on the label alone.
  static const Color weatherAir = Color(0xFFFB7185);
  static const Color weatherTrack = Color(0xFFF59E0B);
  static const Color weatherHumidity = Color(0xFF38BDF8);
  static const Color weatherWind = Color(0xFF2DD4BF);

  /// FIA 플래그/세이프티카 상태 전용 의미 색상. 일반 강조 UI에는 사용하지 않는다.
  static const Color flagYellow = Color(0xFFFACC15);
  static const Color flagRed = Color(0xFFEF4444);
  static const Color warningAmber = Color(0xFFF59E0B);

  /// 타이밍 보드 '세션 전체 최고 기록' 의미색(퍼플) — F1 중계 관례색.
  static const Color timingPurple = Color(0xFFC084FC);

  static Color get muted => palette.muted;
  static Color get nameMuted => palette.nameMuted;
  static Color get heroSub => palette.heroSub;
  // 가장 흐린 텍스트(순위 컬럼 헤더 등). textEnded 와 같은 값.
  static Color get faint => palette.textEnded;

  static Color get tileSurface => palette.tileSurface;
  static Color get hairline => palette.hairline;
  static Color get divider => palette.divider;
  static Color get faintBorder => palette.faintBorder;
  static Color get rowBorder => palette.rowBorder;
  static Color get black20 => palette.black20;

  // 일부 화면이 진한 배경을 참조할 때 쓰는 별칭.
  static Color get black => palette.background;

  static Color get resultRowSurface => palette.resultRowSurface;
  static Color get resultChipSurface => palette.resultChipSurface;
  static Color get textSoft => palette.textSoft;

  static Color get dotInactive => palette.dotInactive;
  static Color get scheduleText => palette.scheduleText;

  static Color get heroAccent => palette.heroAccent;
  static Color get heroAccentBright => palette.heroAccentBright;
  static Color get heroGradTop => palette.heroGradTop;
  static Color get heroGradMid => palette.heroGradMid;
  static Color get heroGradBottom => palette.heroGradBottom;
  static Color get heroMeta => palette.heroMeta;
  static Color get heroSubText => palette.heroSubText;
  static Color get heroDim => palette.heroDim;
  static Color get heroRowText => palette.heroRowText;
  static Color get heroDotIdle => palette.heroDotIdle;

  static Color get panelSurface => palette.panelSurface;
  static Color get heroListSurface => palette.heroListSurface;
  static Color get metallic => palette.metallic;
  static Color get circuitBand => palette.circuitBand;
  static Color get circuitLabel => palette.circuitLabel;
  static Color get scrimPill => palette.scrimPill;
  static Color get scrimPillText => palette.scrimPillText;
  static Color get controlSurface => palette.controlSurface;
  static Color get tyreSoftLabel => palette.tyreSoftLabel;
  static Color get tyreMediumLabel => palette.tyreMediumLabel;
  static Color get tyreHardLabel => palette.tyreHardLabel;
}
