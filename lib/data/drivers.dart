import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 2026 시즌 드라이버 코드(TLA) 기준 매핑 모음.
///
/// 라이브 UI(순위 패널/홈 카드)와 Android 홈 위젯이 함께 쓴다.
/// 시즌 라인업·이적이 생기면 이 파일만 갱신하면 된다.

/// 드라이버 코드 → 한글 이름.
const Map<String, String> driverNameKoByCode = {
  'NOR': '랜도 노리스',
  'PIA': '오스카 피아스트리',
  'VER': '막스 베르스타펜',
  'TSU': '유키 츠노다',
  'LEC': '샤를 르클레르',
  'HAM': '루이스 해밀턴',
  'RUS': '조지 러셀',
  'ANT': '키미 안토넬리',
  'SAI': '카를로스 사인츠',
  'ALB': '알렉산더 알본',
  'ALO': '페르난도 알론소',
  'STR': '랜스 스트롤',
  'GAS': '피에르 가슬리',
  'COL': '프랑코 콜라핀토',
  'OCO': '에스테반 오콘',
  'BEA': '올리버 베어먼',
  'HAD': '아이작 하자르',
  'LAW': '리암 로슨',
  'HUL': '니코 휠켄베르크',
  'BOR': '가브리엘 보르톨레토',
  'BOT': '발테리 보타스',
  'PER': '세르히오 페레즈',
  'LIN': '아비드 린드블라드',
};

/// 웹 driverAccentColor 매핑(드라이버 코드 → 팀 컬러). 노란색은 사용하지 않는다.
const Map<String, int> _driverAccent = {
  'NOR': 0xFFFF8700,
  'PIA': 0xFFFF8700,
  'VER': 0xFF1E41FF,
  'TSU': 0xFF1E41FF,
  'LEC': 0xFFE80020,
  'HAM': 0xFFE80020,
  'RUS': 0xFF00D2BE,
  'ANT': 0xFF00D2BE,
  'SAI': 0xFF00A3FF,
  'ALB': 0xFF00A3FF,
  'ALO': 0xFF229971,
  'STR': 0xFF229971,
  'GAS': 0xFFFF87BC,
  'COL': 0xFFFF87BC,
  'OCO': 0xFFF4F4F4,
  'BEA': 0xFFF4F4F4,
  'HAD': 0xFF6CC3FF,
  'LAW': 0xFF6CC3FF,
  'HUL': 0xFF4B5563, // 아우디(2026) — 순위 페이지와 동일한 짙은 회색
  'BOR': 0xFF4B5563,
};

/// 드라이버 코드의 팀 컬러 액센트. 매핑에 없으면 muted 회색.
Color liveDriverAccent(String code) =>
    Color(_driverAccent[code] ?? AppColors.muted.toARGB32());

/// 드라이버 코드의 한글 이름. 매핑에 없으면 [fallback](원문 이름 등)을 쓴다.
String driverNameKo(String code, String fallback) {
  return driverNameKoByCode[code.trim().toUpperCase()] ?? fallback;
}
