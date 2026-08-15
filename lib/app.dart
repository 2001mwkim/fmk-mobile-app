import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/calendar_screen.dart';
import 'screens/home_screen.dart';
import 'screens/live_center_screen.dart';
import 'screens/standings_screen.dart';
import 'services/fmk_home_widget_bridge.dart';
import 'services/notification_settings_controller.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/bottom_nav.dart';

class FmkApp extends StatelessWidget {
  const FmkApp({super.key, this.runStartupPrompts = true});

  /// 첫 실행 알림 권유 등 시작 시 1회성 프롬프트 실행 여부(위젯 테스트에서 off).
  final bool runStartupPrompts;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '비아 포뮬러',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: MainShell(runStartupPrompts: runStartupPrompts),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.runStartupPrompts = true});

  final bool runStartupPrompts;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // 첫 실행 알림 권유를 1회만 노출하기 위한 shared_preferences 키.
  static const String _notifPromptKey = 'notif_optin_prompted_v1';

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
    if (widget.runStartupPrompts) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybePromptNotificationOptIn(),
      );
    }
  }

  /// 첫 실행 시 세션 알림을 켤지 1회 물어본다. 지금까지는 사용자가 설정에
  /// 들어가 토글해야만 권한을 요청해, 대다수가 알림을 못 받았다. 맥락을 먼저
  /// 보여준 뒤 권한을 요청하는 Android 권장 방식.
  Future<void> _maybePromptNotificationOptIn() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_notifPromptKey) ?? false) return;

      // 이미 알림을 켠 사용자에겐 다시 묻지 않는다.
      final current = await notificationSettingsController.load();
      if (current.hasAnyEnabled) {
        await prefs.setBool(_notifPromptKey, true);
        return;
      }
      if (!mounted) return;

      final wantsOn = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text(
            '레이스 시작 알림 받기',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            '레이스 시작 30분 전에 알려드려요.\n'
            '연습·퀄리 등 다른 세션 알림은 설정에서 켤 수 있어요.',
            style: TextStyle(
              color: AppColors.nameMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('나중에', style: TextStyle(color: AppColors.muted)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('알림 받기'),
            ),
          ],
        ),
      );

      await prefs.setBool(_notifPromptKey, true);
      if (wantsOn != true || !mounted) return;

      final result = await notificationSettingsController.update(
        raceOnly30m: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            result.permissionDenied
                ? '알림 권한이 거부되어 켜지 못했어요. 설정에서 다시 켤 수 있어요.'
                : '레이스 시작 알림을 켰어요.',
          ),
        ),
      );
    } catch (_) {
      // shared_preferences/알림 플러그인 미가용(테스트 등) — 조용히 무시.
    }
  }

  @override
  void dispose() {
    // EventChannel.cancel() 은 네이티브 스트림이 이미 정리됐을 때
    // "No active stream to cancel" 을 던진다(앱 종료 흐름의 무해한 경합).
    // .listen 의 onError 는 데이터 경로만 잡으므로 여기서 별도로 삼켜
    // unhandled 로 새어 Sentry fatal 로 집계되지 않게 한다.
    _widgetClickSub?.cancel().catchError((Object _) {});
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
