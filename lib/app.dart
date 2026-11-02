import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'screens/calendar_screen.dart';
import 'screens/home_screen.dart';
import 'screens/live_center_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/standings_screen.dart';
import 'services/app_theme_controller.dart';
import 'services/fmk_home_widget_bridge.dart';
import 'services/app_update_service.dart';
import 'services/error_reporting.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/bottom_nav.dart';

class FmkApp extends StatelessWidget {
  const FmkApp({super.key, this.runStartupPrompts = true});

  /// 첫 실행 알림 권유 등 시작 시 1회성 프롬프트 실행 여부(위젯 테스트에서 off).
  final bool runStartupPrompts;

  @override
  Widget build(BuildContext context) {
    // 테마 전환 시 MaterialApp 전체를 리빌드한다 — AppColors 가 정적 getter 라
    // 하위 위젯도 리빌드 한 번이면 새 팔레트를 읽는다(부분 리빌드 불가 구조).
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: appThemeController.notifier,
      builder: (context, mode, _) {
        // 앱에 AppBar 가 없어 상태바 아이콘 밝기를 아무도 안 정한다 —
        // 라이트 테마에서 흰 아이콘이 흰 배경에 묻히지 않게 명시한다.
        final isLight = AppColors.brightness == Brightness.light;
        final overlay =
            (isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light)
                .copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.navSurface,
          systemNavigationBarIconBrightness:
              isLight ? Brightness.dark : Brightness.light,
        );
        return MaterialApp(
          key: ValueKey<AppThemeMode>(mode),
          title: '비아 포뮬러',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.current(),
          home: AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlay,
            child: MainShell(runStartupPrompts: runStartupPrompts),
          ),
        );
      },
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
  // 첫 실행 온보딩 완료 여부(2026-11 알림 권유 팝업을 대체).
  static const String _onboardingKey = 'onboarding_completed_v1';

  int _currentIndex = 0;
  StreamSubscription<Uri?>? _widgetClickSub;

  // 하단 탭과 1:1 인덱스 매핑(BottomNav._items 순서와 함께 수정할 것).
  // 소식/직관 화면 파일은 유지하되, 하단 탭은 라이브 센터를 사용한다.
  // 홈의 TOP 3 카드가 순위 탭(인덱스 2)으로 점프할 수 있게 콜백을 연결한다.
  late final List<Widget?> _screens;

  @override
  void initState() {
    super.initState();
    _screens = <Widget?>[
      HomeScreen(
        onOpenStandings: () => _onTabSelected(2),
        onOpenLiveCenter: () => _onTabSelected(3),
      ),
      null,
      null,
      null,
    ];
    _bindWidgetLaunch();
    // 테마 전환 리마운트 직후라면 설정 화면을 즉시(무애니메이션) 복원한다 —
    // 사용자는 설정에서 테마를 바꿨는데 홈으로 튕기면 어색하다.
    if (appThemeController.consumeReopenSettings()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(
          PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, _, _) => const SettingsScreen(),
          ),
        );
      });
    }
    if (widget.runStartupPrompts) {
      WidgetsBinding.instance.addPostFrameCallback(
        // 겹치지 않게 순차: 첫 실행 온보딩 → 업데이트 권장.
        (_) => _maybeRunOnboarding().then(
          (_) => _maybePromptAppUpdate(),
        ),
      );
    }
  }

  /// 새 버전이 스토어에 올라오면 하루 1회 업데이트를 권한다. 버전 정보는
  /// collector 의 app-version.json(사람이 심사 통과 후 올림) — 자세한 규칙은
  /// [AppUpdateService]/[AppUpdateGate]. minSupported 미만이면 닫을 수 없다.
  Future<void> _maybePromptAppUpdate() async {
    try {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final gate = AppUpdateGate(prefs);
      final now = DateTime.now();
      if (!gate.shouldCheck(now)) return;

      const service = AppUpdateService();
      final info = await service.fetch();
      await gate.markChecked(now);
      if (info == null || !mounted) return;

      final verdict = decideAppUpdate(
        current: service.currentVersion,
        info: info,
      );
      if (verdict == AppUpdateVerdict.none) return;
      if (gate.isSkipped(info, verdict)) return;

      final mandatory = verdict == AppUpdateVerdict.mandatory;
      final open = await showDialog<bool>(
        context: context,
        barrierDismissible: !mandatory,
        builder: (dialogContext) => PopScope(
          canPop: !mandatory,
          child: _AppUpdateDialog(
            message: info.message,
            mandatory: mandatory,
            onLater: () => Navigator.of(dialogContext).pop(false),
            onUpdate: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
      );
      if (open != true) {
        if (!mandatory) await gate.skip(info);
        return;
      }
      await launchUrl(
        Uri.parse(info.storeUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (error, stackTrace) {
      // 네트워크/prefs/url_launcher 실패는 사용자에겐 조용히 넘긴다 — 팝업은 부가 기능.
      reportSilentFailure('app_update_prompt', error, stackTrace);
    }
  }

  /// 첫 실행이면 온보딩(소개 → MY PICKS → 알림)을 1회 띄운다.
  ///
  /// 종전의 알림 권유 팝업(`_notifPromptKey`)을 대체한다. 그 팝업을 이미 본
  /// 기존 사용자에겐 온보딩을 보여주지 않는다 — 업데이트 직후 갑자기 소개
  /// 화면이 뜨면 새 앱을 깐 것처럼 어색하다.
  Future<void> _maybeRunOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_onboardingKey) ?? false) return;
      if (prefs.getBool(_notifPromptKey) ?? false) {
        await prefs.setBool(_onboardingKey, true);
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const OnboardingScreen(),
        ),
      );
      // 중간에 앱이 종료되면 다음 실행에 다시 보여주도록 끝난 뒤에 기록한다.
      await prefs.setBool(_onboardingKey, true);
      await prefs.setBool(_notifPromptKey, true);
    } catch (error, stackTrace) {
      // shared_preferences 미가용(테스트 등) — 사용자에겐 조용히 넘긴다.
      reportSilentFailure('onboarding', error, stackTrace);
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
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
      return;
    }
    final index = fmkWidgetTabIndexForUri(uri);
    if (index == null) return;
    _onTabSelected(index);
  }

  void _onTabSelected(int index) {
    setState(() {
      _screens[index] ??= switch (index) {
        1 => const CalendarScreen(),
        2 => const StandingsScreen(),
        3 => const LiveCenterScreen(),
        _ => _screens.first!,
      };
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 탭 바가 떠 있는 유리 캡슐이라 콘텐츠가 그 아래로 흘러 비쳐 보여야 한다.
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          for (final screen in _screens) screen ?? const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}

/// 업데이트 권장/강제 팝업 — [_NotificationOptInDialog] 와 같은 톤.
/// [mandatory] 면 "나중에"가 없고 배리어/뒤로가기로 닫히지 않는다(호출부 PopScope).
class _AppUpdateDialog extends StatelessWidget {
  const _AppUpdateDialog({
    required this.message,
    required this.mandatory,
    required this.onLater,
    required this.onUpdate,
  });

  final String message;
  final bool mandatory;
  final VoidCallback onLater;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.heroGradTop, AppColors.card],
          ),
          border: Border.all(color: AppColors.heroAccent.withValues(alpha: 0.2)),
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.heroAccent.withValues(alpha: 0.07),
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
                      color: AppColors.heroAccent.withValues(alpha: 0.12),
                      border: Border.all(
                        color: AppColors.heroAccent.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.system_update_alt_rounded,
                      color: AppColors.heroAccentBright,
                      size: 25,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    mandatory ? '업데이트가 필요해요' : '새 버전이 나왔어요',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      height: 1.3,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mandatory
                        ? '이 버전은 더 이상 지원되지 않아요. 계속 쓰려면 업데이트해 주세요.'
                        : message,
                    style: TextStyle(
                      color: AppColors.nameMuted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (!mandatory) ...[
                        TextButton(
                          onPressed: onLater,
                          child: Text(
                            '나중에',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.red,
                            foregroundColor: AppColors.onAccent,
                            minimumSize: const Size(0, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: onUpdate,
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text(
                            '업데이트',
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
