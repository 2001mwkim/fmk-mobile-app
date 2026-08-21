import 'package:flutter/material.dart';

/// 화면마다 임의 값을 만들지 않도록 제한한 공통 레이아웃 토큰.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadius {
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;

  static const BorderRadius smallBorder = BorderRadius.all(
    Radius.circular(small),
  );
  static const BorderRadius mediumBorder = BorderRadius.all(
    Radius.circular(medium),
  );
  static const BorderRadius largeBorder = BorderRadius.all(
    Radius.circular(large),
  );
}

abstract final class AppInsets {
  static const EdgeInsets screen = EdgeInsets.fromLTRB(16, 12, 16, 24);
}

/// 폰보다 넓은 화면(iPad 가로 등)에서 본문이 화면 전폭으로 늘어나지 않게 하는
/// 레이아웃 토큰. 웹 UI 이식 디자인이 세로 폰 폭 기준이라 그대로 늘리면 카드
/// 한 줄이 지나치게 길어져 읽기 힘들다. 넘치는 폭은 좌우 여백으로 돌린다.
abstract final class AppLayout {
  /// 본문 최대 폭. 이보다 넓어지면 남는 폭은 전부 좌우 여백이 된다.
  /// 720 은 iPad 11" 가로(1194)에서도 카드 비율이 폰과 크게 달라지지 않는 값.
  static const double maxContentWidth = 720;

  /// 화면 폭이 [maxContentWidth] 를 넘을 때 한쪽에 추가로 붙는 여백.
  static double contentGutter(BuildContext context) {
    final extra = (MediaQuery.sizeOf(context).width - maxContentWidth) / 2;
    return extra > 0 ? extra : 0;
  }

  /// 각 화면 최상위 스크롤뷰의 패딩. ListView 를 ConstrainedBox 로 감싸는 대신
  /// 패딩으로 처리하는 이유는 스크롤 제스처와 스크롤바를 화면 전폭에 유지하기
  /// 위해서다(가장자리를 쓸어도 스크롤된다).
  static EdgeInsets pagePadding(
    BuildContext context, {
    double top = 12,
    double bottom = 24,
    double horizontal = 16,
  }) {
    final gutter = horizontal + contentGutter(context);
    return EdgeInsets.fromLTRB(gutter, top, gutter, bottom);
  }
}
