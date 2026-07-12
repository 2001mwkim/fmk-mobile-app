import 'package:flutter/material.dart';

import 'screens/calendar_screen.dart';
import 'screens/home_screen.dart';
import 'screens/live_center_screen.dart';
import 'screens/standings_screen.dart';
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

  // 하단 탭과 1:1 인덱스 매핑(BottomNav._items 순서와 함께 수정할 것).
  // 소식/직관 화면 파일은 유지하되, 하단 탭은 라이브 센터를 사용한다.
  // 홈의 TOP 3 카드가 순위 탭(인덱스 2)으로 점프할 수 있게 콜백을 연결한다.
  late final List<Widget> _screens = <Widget>[
    HomeScreen(onOpenStandings: () => _onTabSelected(2)),
    const CalendarScreen(),
    const StandingsScreen(),
    const LiveCenterScreen(),
  ];

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
