import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/calendar_screen.dart';
import 'screens/home_screen.dart';
import 'screens/live_center_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/standings_screen.dart';
import 'services/fmk_home_widget_bridge.dart';
import 'services/notification_service.dart';
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
    HomeScreen(
      onOpenStandings: () => _onTabSelected(2),
      onOpenLiveCenter: () => _onTabSelected(3),
    ),
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
        builder: (dialogContext) => _NotificationOptInDialog(
          onLater: () => Navigator.of(dialogContext).pop(false),
          onEnable: () => Navigator.of(dialogContext).pop(true),
        ),
      );

      await prefs.setBool(_notifPromptKey, true);
      if (wantsOn != true || !mounted) return;

      final result = await notificationSettingsController.update(
        category: SessionCategory.race,
        enabled: true,
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
    // 위젯 클릭 스트림 구독 해제. 단, 이때 프레임워크가 네이티브 스트림
    // 해제 중 "No active stream to cancel" 을 FlutterError 로 재보고할 수
    // 있는데(무해), 그건 앱 코드에서 못 잡으므로 main.dart 의 Sentry
    // beforeSend(_isBenignStreamCancel) 에서 걸러낸다.
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
    if (!mounted) return;
    // MY DRIVER/MY TEAM 위젯 탭 → 설정(MY PICKS 섹션). 미설정 위젯의
    // "앱에서 설정" 안내가 한 번의 탭으로 선택기까지 닿게 한다.
    if (fmkWidgetOpensMyPicks(uri)) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      );
      return;
    }
    final index = fmkWidgetTabIndexForUri(uri);
    if (index == null) return;
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

class _NotificationOptInDialog extends StatelessWidget {
  const _NotificationOptInDialog({
    required this.onLater,
    required this.onEnable,
  });

  final VoidCallback onLater;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.heroGradTop, AppColors.card],
          ),
          border: Border.all(color: const Color(0x33F25C5C)),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -42,
              top: -54,
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x12F25C5C),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0x1FF25C5C),
                      border: Border.all(color: const Color(0x4DF25C5C)),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      color: AppColors.heroAccentBright,
                      size: 25,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '레이스 시작을 놓치지 마세요',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      height: 1.3,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '레이스 시작 30분 전에 알림을 보내드려요.',
                    style: TextStyle(
                      color: AppColors.nameMuted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.black20,
                      border: Border.all(color: AppColors.hairline),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: AppColors.redSoft,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '연습 · 퀄리 · 스프린트도 원하는 세션만 선택할 수 있어요',
                            style: TextStyle(
                              color: AppColors.heroSub,
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      TextButton(
                        onPressed: onLater,
                        child: const Text(
                          '다음에',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.red,
                            foregroundColor: AppColors.white,
                            minimumSize: const Size(0, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: onEnable,
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            '레이스 알림 켜기',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
