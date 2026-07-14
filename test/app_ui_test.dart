import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/theme/app_theme.dart';
import 'package:fmk_app/widgets/app_ui.dart';

void main() {
  testWidgets('핵심 공통 UI가 작은 화면과 큰 글자에서도 overflow 없이 그려진다', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in <double>[360, 390, 430]) {
      for (final scale in <double>[1, 1.3, 1.6]) {
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark(),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 800),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const AppPageHeader(
                      eyebrow: '2026 시즌 기준',
                      title: '챔피언십 순위',
                      description: '실시간 순위와 세션 상황을 한곳에서 확인하세요.',
                    ),
                    const SizedBox(height: 16),
                    AppSegmentedControl<int>(
                      values: const [0, 1, 2, 3],
                      selected: 0,
                      labelFor: (value) =>
                          const ['전체', '예정', '진행중', '종료'][value],
                      onChanged: (_) {},
                    ),
                    const AppStateView(
                      message: '표시할 데이터가 없습니다.\n잠시 후 다시 확인해주세요.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull, reason: '$width px / $scale 배율');
      }
    }
  });

  testWidgets('세그먼트 전체 영역이 탭 가능하다', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: AppSegmentedControl<int>(
            values: const [0, 1],
            selected: selected,
            labelFor: (value) => value == 0 ? '드라이버' : '컨스트럭터',
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('컨스트럭터'));
    expect(selected, 1);
  });
}
