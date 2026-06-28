import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/app.dart';

void main() {
  testWidgets('bottom tabs and settings navigation work', (tester) async {
    await tester.pumpWidget(const FmkApp());

    expect(find.text('포매코'), findsOneWidget);
    expect(find.text('홈'), findsWidgets);
    expect(find.text('일정'), findsOneWidget);
    expect(find.text('순위'), findsOneWidget);
    expect(find.text('직관'), findsOneWidget);
    expect(find.text('다음 그랑프리'), findsOneWidget);
    expect(find.text('다음 세션'), findsOneWidget);
    expect(find.text('시즌 진행 상황'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('전체 일정 보기'), 200);
    expect(find.text('전체 일정 보기'), findsOneWidget);

    await tester.tap(find.text('일정'));
    await tester.pumpAndSettle();
    expect(find.text('2026 시즌 캘린더'), findsOneWidget);
    expect(find.text('24개 그랑프리'), findsOneWidget);
    expect(find.text('호주 그랑프리'), findsOneWidget);

    await tester.tap(find.text('순위'));
    await tester.pumpAndSettle();
    expect(find.text('드라이버와 컨스트럭터 순위가 표시될 예정입니다.'), findsOneWidget);

    await tester.tap(find.text('직관'));
    await tester.pumpAndSettle();
    expect(find.text('그랑프리 직관 정보와 여행 메모가 표시될 예정입니다.'), findsOneWidget);

    await tester.tap(find.text('홈'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('설정'), findsOneWidget);
    expect(find.text('앱 설정 항목이 추가될 예정입니다.'), findsOneWidget);
  });
}
