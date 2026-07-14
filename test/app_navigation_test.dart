import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/app.dart';

void main() {
  testWidgets('bottom tabs, race detail, and settings navigation work', (
    tester,
  ) async {
    await tester.pumpWidget(const FmkApp());

    expect(find.text('Via Formula'), findsOneWidget);
    expect(find.text('F1 관련 정보를 내 손안에'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.text('홈'), findsWidgets);
    expect(find.text('일정'), findsOneWidget);
    expect(find.text('순위'), findsOneWidget);
    expect(find.text('라이브'), findsOneWidget);
    // 히어로 상태 칩은 시점에 따라 '다음 그랑프리' 또는 '진행중'으로 표시된다.
    expect(
      find.text('다음 그랑프리').evaluate().isNotEmpty ||
          find.text('진행중').evaluate().isNotEmpty,
      isTrue,
    );
    // 주말 일정은 히어로 카드에 통합됨(별도 '이번 주말 일정' 카드 제거).
    expect(find.text('이번 주말 일정'), findsNothing);
    expect(find.text('한국 시간 (KST) 기준'), findsNothing);
    // 홈 하단: 챔피언십 TOP 3 미리보기 + 빠른 설정(알림/위젯 진입점).
    expect(find.text('챔피언십 TOP 3'), findsOneWidget);
    expect(find.text('위젯 추가'), findsOneWidget);

    await tester.tap(find.text('일정'));
    await tester.pumpAndSettle();
    expect(find.text('시즌 캘린더'), findsOneWidget);
    expect(find.text('다가오는 그랑프리'), findsOneWidget);
    expect(find.text('전체'), findsOneWidget);
    expect(find.text('예정'), findsWidgets);
    expect(find.text('진행중'), findsWidgets);
    expect(find.text('종료'), findsWidgets);

    await tester.tap(find.text('종료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('호주 그랑프리'));
    await tester.pumpAndSettle();
    expect(find.text('일정으로'), findsOneWidget);
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
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.text('순위'));
    await tester.pumpAndSettle();
    expect(find.text('챔피언십 순위'), findsOneWidget);
    expect(find.text('키미 안토넬리'), findsOneWidget);
    await tester.tap(find.text('컨스트럭터'));
    await tester.pumpAndSettle();
    expect(find.text('키미 안토넬리'), findsNothing);
    expect(find.text('메르세데스'), findsWidgets);

    // 소식 탭을 라이브 센터로 교체했다. 비라이브 때는 다음 세션과
    // 세션 중 제공될 핵심 데이터를 한 패널에서 안내한다.
    await tester.tap(find.text('라이브'));
    await tester.pumpAndSettle();
    expect(find.text('직관'), findsNothing);
    expect(find.text('라이브 센터'), findsOneWidget);
    expect(find.text('다음 라이브'), findsOneWidget);
    // 비라이브에도 실시간 순위/날씨/레이스 컨트롤의 정보 구조를 유지한다.
    expect(find.text('실시간 순위'), findsOneWidget);
    expect(find.text('트랙 & 날씨'), findsOneWidget);
    expect(find.text('레이스 컨트롤'), findsOneWidget);

    await tester.tap(find.text('홈'));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ListView).first, const Offset(0, 800), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('설정'), findsWidgets);
    expect(find.text('일정 관리'), findsNothing);
    expect(find.text('캘린더에 추가'), findsNothing);
    expect(find.text('알림 설정'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('인스타그램 보러가기'), 200);
    expect(find.text('인스타그램 보러가기'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('F1DB · CC BY 4.0'), 200);
    expect(find.text('F1DB · CC BY 4.0'), findsOneWidget);
    // 설정 최하단 개인정보 처리방침 링크
    await tester.scrollUntilVisible(find.text('개인정보 처리방침'), 200);
    expect(find.text('개인정보 처리방침'), findsOneWidget);
  });
}
