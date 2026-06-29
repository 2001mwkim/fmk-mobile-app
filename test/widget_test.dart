import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/app.dart';

void main() {
  testWidgets('bottom tabs, race detail, and settings navigation work', (
    tester,
  ) async {
    await tester.pumpWidget(const FmkApp());

    expect(find.text('포매코'), findsOneWidget);
    expect(find.text('홈'), findsWidgets);
    expect(find.text('일정'), findsOneWidget);
    expect(find.text('순위'), findsOneWidget);
    expect(find.text('직관'), findsOneWidget);
    expect(find.text('다음 그랑프리'), findsOneWidget);
    expect(find.text('다음 세션'), findsOneWidget);
    expect(find.text('이번 주말 일정'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('시즌 진행 상황'), 200);
    expect(find.text('시즌 진행 상황'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('전체 일정 보기'), 200);
    expect(find.text('전체 일정 보기'), findsOneWidget);

    await tester.tap(find.text('일정'));
    await tester.pumpAndSettle();
    expect(find.text('2026 시즌 캘린더'), findsOneWidget);
    expect(find.text('24개 그랑프리'), findsOneWidget);
    expect(find.text('전체'), findsOneWidget);
    expect(find.text('예정'), findsWidgets);
    expect(find.text('진행중'), findsWidgets);
    expect(find.text('종료'), findsWidgets);

    await tester.tap(find.text('종료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('호주 그랑프리'));
    await tester.pumpAndSettle();
    expect(find.text('레이스 결과'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('레이스 시작'), 200);
    expect(find.text('레이스 시작'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('세션 일정'), 200);
    expect(find.text('세션 일정'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('서킷 정보'), 200);
    expect(find.text('서킷 정보'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Circuit layouts: F1DB (CC BY 4.0)'),
      200,
    );
    expect(find.text('Circuit layouts: F1DB (CC BY 4.0)'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('순위'));
    await tester.pumpAndSettle();
    expect(find.text('드라이버 순위'), findsOneWidget);
    expect(find.text('키미 안토넬리'), findsOneWidget);
    await tester.tap(find.text('컨스트럭터'));
    await tester.pumpAndSettle();
    expect(find.text('컨스트럭터 순위'), findsOneWidget);
    expect(find.text('메르세데스'), findsOneWidget);

    await tester.tap(find.text('직관'));
    await tester.pumpAndSettle();
    expect(find.text('직관 가이드'), findsWidgets);
    expect(find.text('GUIDE IN PROGRESS'), findsOneWidget);
    expect(find.text('아시아 그랑프리 직관 정보 준비 중'), findsOneWidget);
    expect(find.text('일본 그랑프리'), findsOneWidget);
    expect(find.text('중국 그랑프리'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('싱가포르 그랑프리'), 200);
    expect(find.text('싱가포르 그랑프리'), findsOneWidget);
    expect(find.text('관련 그랑프리'), findsWidgets);
    expect(find.text('직관 정보 준비 중'), findsWidgets);

    await tester.tap(find.text('홈'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('설정'), findsWidgets);
    expect(find.text('일정 관리'), findsOneWidget);
    expect(find.text('캘린더에 추가'), findsOneWidget);
    expect(find.text('알림 설정'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('인스타그램 보러가기'), 200);
    expect(find.text('인스타그램 보러가기'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('F1DB · CC BY 4.0'), 200);
    expect(find.text('F1DB · CC BY 4.0'), findsOneWidget);
  });
}
