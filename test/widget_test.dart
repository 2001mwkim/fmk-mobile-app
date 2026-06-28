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

    await tester.tap(find.text('일정'));
    await tester.pumpAndSettle();
    expect(find.text('레이스 캘린더와 세션 일정이 표시될 예정입니다.'), findsOneWidget);

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
