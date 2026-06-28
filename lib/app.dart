import 'package:flutter/material.dart';

import 'screens/calendar_screen.dart';
import 'screens/home_screen.dart';
import 'screens/standings_screen.dart';
import 'screens/visit_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/bottom_nav.dart';

class FmkApp extends StatelessWidget {
  const FmkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '포매코',
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

  static const List<Widget> _screens = [
    HomeScreen(),
    CalendarScreen(),
    StandingsScreen(),
    VisitScreen(),
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
