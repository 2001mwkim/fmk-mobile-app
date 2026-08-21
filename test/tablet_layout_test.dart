import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/app.dart';
import 'package:fmk_app/theme/app_tokens.dart';
import 'package:fmk_app/widgets/bottom_nav.dart';

/// iPad 가로처럼 폰보다 넓은 화면에서 본문이 화면 전폭으로 늘어나지 않고
/// AppLayout.maxContentWidth 로 가운데 정렬되는지 검증한다.
void main() {
  /// 홈 최상위 ListView 의 좌우 패딩(= 16 + 좌우 여백).
  EdgeInsets homeListPadding(WidgetTester tester) {
    final list = tester.widget<ListView>(find.byType(ListView).first);
    return list.padding! as EdgeInsets;
  }

  Future<void> pumpAt(WidgetTester tester, Size logicalSize) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = logicalSize * 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const FmkApp(runStartupPrompts: false));
  }

  testWidgets('폰 폭에서는 기존 16 패딩을 그대로 쓴다', (tester) async {
    await pumpAt(tester, const Size(390, 844));

    final padding = homeListPadding(tester);
    expect(padding.left, 16);
    expect(padding.right, 16);
  });

  testWidgets('iPad 가로 폭에서는 본문이 최대 폭으로 가운데 정렬된다', (tester) async {
    const width = 1194.0; // iPad 11" 가로
    await pumpAt(tester, const Size(width, 834));

    final expectedGutter = 16 + (width - AppLayout.maxContentWidth) / 2;
    final padding = homeListPadding(tester);
    expect(padding.left, expectedGutter);
    expect(padding.right, expectedGutter);
    // 본문(패딩 제외)은 딱 최대 폭이다.
    expect(width - padding.horizontal, AppLayout.maxContentWidth - 32);

    // 하단 탭도 같은 폭에 맞춘다 — 본문만 좁고 탭만 벌어지면 어긋나 보인다.
    // (SafeArea 가 삽입하는 Padding 도 섞이므로 좌우 여백이 일치하는 것을 찾는다.)
    final navPaddings = tester
        .widgetList<Padding>(
          find.descendant(
            of: find.byType(BottomNav),
            matching: find.byType(Padding),
          ),
        )
        .map((padding) => padding.padding.resolve(TextDirection.ltr).left);
    expect(navPaddings, contains(expectedGutter));
  });

  testWidgets('iPad 가로 크기에서 네 탭 모두 오버플로 없이 그려진다', (tester) async {
    // 세로가 짧아지는 가로 화면(834pt)에서 히어로/순위 카드가 넘치지 않는지
    // 확인한다 — RenderFlex 오버플로가 나면 이 테스트가 실패한다.
    await pumpAt(tester, const Size(1194, 834));

    for (final tab in ['일정', '순위', '라이브', '홈']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$tab 탭 렌더링 실패');
    }
  });
}
