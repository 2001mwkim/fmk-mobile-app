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

/// 타입 스케일(2026-10 디자인 정리). 화면 코드에 fontSize/fontWeight 를 직접
/// 적지 말고 이 6단계 중 하나를 골라 색만 copyWith 로 입힌다.
///
/// 기준은 iOS 기본 앱(애플 스포츠 등)의 위계: 굵기는 w700 이하로 두고 위계는
/// 크기·색 대비로 만든다. 이전 디자인은 w800~w900 이 대부분이라 전부 강조돼
/// 아무것도 강조되지 않았다. 색은 테마 getter 라 여기 넣지 않는다.
abstract final class AppType {
  /// 화면 제목(라지 타이틀).
  static const TextStyle largeTitle = TextStyle(
    fontSize: 30,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
  );

  /// 카드의 주인공(GP명 등)·섹션 제목.
  static const TextStyle title = TextStyle(
    fontSize: 22,
    height: 1.27,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  /// 목록 행 강조, 소제목.
  static const TextStyle headline = TextStyle(
    fontSize: 16,
    height: 1.35,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  /// 본문·목록 행 기본.
  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
  );

  /// 보조 설명, 메타 정보.
  static const TextStyle subhead = TextStyle(
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );

  /// 가장 작은 단계. 이보다 작은 글자는 쓰지 않는다(이전 디자인의 9~10pt
  /// 라벨은 실기기에서 거의 읽히지 않았다). 예외는 하단 탭 바 라벨(11)뿐.
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  /// 시간·갭·포인트처럼 갱신되거나 세로로 비교하는 숫자에 붙인다.
  /// 비례폭 숫자는 값이 바뀔 때마다 글자 폭이 달라져 좌우로 흔들린다.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];
}

abstract final class AppRadius {
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;

  /// 카드 표면 공통 모서리. 홈·목록 카드가 모두 이 값을 쓴다.
  static const double card = 18;
  static const BorderRadius cardBorder = BorderRadius.all(
    Radius.circular(card),
  );

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
    // 떠 있는 글래스 탭 바(Scaffold.extendBody) 아래로 콘텐츠가 흐르는 탭
    // 화면에선 MediaQuery 하단 패딩에 바 높이가 들어 있다 — 마지막 항목이
    // 바에 가리지 않게 그만큼 더 띄운다. SafeArea 안쪽 화면에선 0 이라 무해.
    final inset = MediaQuery.paddingOf(context).bottom;
    return EdgeInsets.fromLTRB(gutter, top, gutter, bottom + inset);
  }
}
