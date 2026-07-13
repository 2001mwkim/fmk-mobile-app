import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/calendar_screen.dart';
import 'screens/home_screen.dart';
import 'screens/live_center_screen.dart';
import 'screens/standings_screen.dart';
import 'services/fmk_home_widget_bridge.dart';
import 'theme/app_theme.dart';
import 'widgets/bottom_nav.dart';

class FmkApp extends StatelessWidget {
  const FmkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '비아 포뮬러',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  StreamSubscription<Uri?>? _widgetClickSub;

  // 하단 탭과 1:1 인덱스 매핑(BottomNav._items 순서와 함께 수정할 것).
  // 소식/직관 화면 파일은 유지하되, 하단 탭은 라이브 센터를 사용한다.
  // 홈의 TOP 3 카드가 순위 탭(인덱스 2)으로 점프할 수 있게 콜백을 연결한다.
  late final List<Widget> _screens = <Widget>[
    HomeScreen(onOpenStandings: () => _onTabSelected(2)),
    const CalendarScreen(),
    const StandingsScreen(),
    const LiveCenterScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _bindWidgetLaunch();
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    super.dispose();
  }

  /// 위젯 탭 딥링크(fmkwidget://live 등) → 해당 하단 탭으로 전환.
  /// 콜드 스타트(앱이 위젯으로 시작)와 웜 스타트(실행 중 위젯 탭) 모두 처리.
  Future<void> _bindWidgetLaunch() async {
    _handleWidgetUri(await FmkHomeWidgetBridge.initialLaunchUri());
    _widgetClickSub = FmkHomeWidgetBridge.widgetClicks().listen(
      _handleWidgetUri,
      // 테스트/플러그인 미등록 환경의 채널 오류는 조용히 무시.
      onError: (Object _) {},
    );
  }

  void _handleWidgetUri(Uri? uri) {
    final index = fmkWidgetTabIndexForUri(uri);
    if (index == null || !mounted) return;
    setState(() => _currentIndex = index);
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}
