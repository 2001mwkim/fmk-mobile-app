import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/app.dart';

void main() {
  testWidgets('bottom tabs, race detail, and settings navigation work', (
    tester,
  ) async {
    await tester.pumpWidget(const FmkApp());

    expect(find.text('2026 시즌'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.text('홈'), findsWidgets);
    expect(find.text('일정'), findsOneWidget);
    expect(find.text('순위'), findsOneWidget);
    expect(find.text('소식'), findsOneWidget);
    // 히어로 상태 칩은 시점에 따라 '다음 그랑프리' 또는 '진행중'으로 표시된다.
    expect(
      find.text('다음 그랑프리').evaluate().isNotEmpty ||
          find.text('진행중').evaluate().isNotEmpty,
      isTrue,
    );
    // 주말 일정은 히어로 카드에 통합됨(별도 '이번 주말 일정' 카드 제거).
    expect(find.text('이번 주말 일정'), findsNothing);
    expect(find.text('한국 시간 (KST) 기준'), findsNothing);

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

    // 직관 탭은 MVP 범위 제외로 소식 탭으로 교체됨.
    // 기본 저장소가 실서버(HttpNewsRepository)라 네트워크가 차단된 테스트
    // 환경에서는 빈 상태 카드가 뜬다(크래시 없음 검증). 카드 렌더링은
    // mock 저장소를 주입하는 news_screen_test 가 담당한다.
    await tester.tap(find.text('소식'));
    await tester.pumpAndSettle();
    expect(find.text('직관'), findsNothing);
    expect(find.text('F1 NEWS BRIEFING'), findsOneWidget);
    expect(find.text('해외 F1 주요 소식을 한국어 브리핑으로 빠르게 확인하세요.'), findsOneWidget);
    expect(find.text('표시할 소식이 없습니다'), findsOneWidget);

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
