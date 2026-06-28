import 'package:flutter/material.dart';

const Map<String, int> teamColorHexMap = {
  '맥라렌': 0xFFFF8700,
  '페라리': 0xFFE80020,
  '메르세데스': 0xFF00D2BE,
  '레드불 레이싱': 0xFF1E41FF,
  '윌리엄스': 0xFF00A3FF,
  '알핀': 0xFFFF87BC,
  '레이싱 불스': 0xFF6CC3FF,
  '하스': 0xFFF4F4F4,
  '킥 자우버': 0xFF52E252,
  '애스턴 마틴': 0xFF006F62,
  '캐딜락': 0xFFD4AF37,
  '아우디': 0xFF4B5563,
};

const int defaultTeamColorHex = 0xFF7880A0;

int getTeamColorHex(String teamKo) {
  return teamColorHexMap[teamKo] ?? defaultTeamColorHex;
}

Color getTeamColor(String teamKo) {
  return Color(getTeamColorHex(teamKo));
}

bool isLightTeamColor(String teamKo) {
  return _relativeLuminance(getTeamColorHex(teamKo)) > 0.8;
}

double _relativeLuminance(int argb) {
  final r = ((argb >> 16) & 0xFF) / 255;
  final g = ((argb >> 8) & 0xFF) / 255;
  final b = (argb & 0xFF) / 255;
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}
