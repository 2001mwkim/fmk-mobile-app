import 'package:flutter/material.dart';

import '../data/drivers.dart';
import '../data/standings.dart' as static_standings;
import '../data/team_colors.dart';
import '../models/standing.dart';
import '../services/fmk_home_widget_bridge.dart';
import '../services/my_picks_controller.dart';
import '../services/notification_service.dart';
import '../services/notification_settings_controller.dart';
import '../services/standings_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../widgets/my_picks_card.dart';

/// 첫 실행 온보딩(3장): 소개 → MY DRIVER·MY TEAM → 알림.
///
/// 종전엔 MY PICKS 와 알림이 설정 안에 숨어 있어 대부분이 기본 상태로 썼다
/// (2026-11 개선 목록). FotMob·OneFootball 처럼 첫 실행에서 응원 대상을 고르고
/// 맥락과 함께 알림 권한을 받는다. 모든 단계는 건너뛸 수 있다.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    this.picksController,
    this.notificationController,
    this.standingsRepository,
    this.onPicksChanged,
  });

  /// 테스트 주입 지점(기본은 앱 전역 인스턴스).
  final MyPicksController? picksController;
  final NotificationSettingsController? notificationController;
  final StandingsRepository? standingsRepository;

  /// MY PICKS 저장 후 호출(기본은 홈 위젯 갱신). 테스트에서 네이티브 호출을 막는다.
  final Future<void> Function()? onPicksChanged;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _pageCount = 3;

  final PageController _pages = PageController();
  int _page = 0;

  List<DriverStanding> _drivers = static_standings.driverStandings;
  List<ConstructorStanding> _teams = static_standings.constructorStandings;

  // 알림 단계 기본값: 놓치면 아쉬운 퀄리파잉·레이스만 켠다(새벽 연습까지
  // 기본으로 켜면 알림을 통째로 끄는 사용자가 생긴다).
  Set<SessionCategory> _categories = {
    SessionCategory.qualifying,
    SessionCategory.race,
  };
  int _leadMinutes = defaultNotificationLeadMinutes;
  bool _resultReminders = false;
  bool _savingNotifications = false;

  MyPicksController get _picks => widget.picksController ?? myPicksController;
  NotificationSettingsController get _notifications =>
      widget.notificationController ?? notificationSettingsController;

  @override
  void initState() {
    super.initState();
    _picks.addListener(_onPicksChanged);
    _picks.load();
    _loadStandings();
  }

  @override
  void dispose() {
    _picks.removeListener(_onPicksChanged);
    _pages.dispose();
    super.dispose();
  }

  void _onPicksChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadStandings() async {
    final repo = widget.standingsRepository ?? const HttpStandingsRepository();
    try {
      final snapshot = await repo.fetchLatest();
      if (!mounted || snapshot == null) return;
      setState(() {
        _drivers = snapshot.driverStandings;
        _teams = snapshot.constructorStandings;
      });
    } catch (_) {
      // 정적 순위로 고른다.
    }
  }

  void _next() {
    if (_page < _pageCount - 1) {
      _pages.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _finish() => Navigator.of(context).pop();

  Future<void> _pickDriver() async {
    final result = await showModalBottomSheet<MyPickResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MyDriverPickerSheet(
        current: _picks.picks.driverCode,
        drivers: _drivers,
      ),
    );
    if (result == null || !mounted) return;
    await _picks.saveDriver(result.clear ? null : result.value);
    await (widget.onPicksChanged ?? FmkHomeWidgetBridge.update)();
  }

  Future<void> _pickTeam() async {
    final result = await showModalBottomSheet<MyPickResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MyTeamPickerSheet(
        current: _picks.picks.teamKo,
        teams: _teams,
        drivers: _drivers,
      ),
    );
    if (result == null || !mounted) return;
    await _picks.saveTeam(result.clear ? null : result.value);
    await (widget.onPicksChanged ?? FmkHomeWidgetBridge.update)();
  }

  Future<void> _enableNotifications() async {
    if (_savingNotifications) return;
    setState(() => _savingNotifications = true);
    var denied = false;
    try {
      final current = await _notifications.load();
      final result = await _notifications.apply(
        current.copyWith(
          categories: _categories,
          leadMinutes: _leadMinutes,
          resultReminders: _resultReminders,
        ),
      );
      denied = result.permissionDenied;
    } catch (_) {
      denied = true;
    }
    if (!mounted) return;
    setState(() => _savingNotifications = false);
    if (denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('알림 권한이 꺼져 있어요. 설정 › 알림에서 다시 켤 수 있어요.'),
        ),
      );
    }
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pageCount - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 8, 0),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    '건너뛰기',
                    style: AppType.subhead.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (index) => setState(() => _page = index),
                children: [
                  const _WelcomePage(),
                  _PicksPage(
                    picks: _picks.picks,
                    onPickDriver: _pickDriver,
                    onPickTeam: _pickTeam,
                  ),
                  _NotificationsPage(
                    categories: _categories,
                    leadMinutes: _leadMinutes,
                    resultReminders: _resultReminders,
                    onCategoryChanged: (category, on) => setState(() {
                      _categories = {..._categories};
                      on
                          ? _categories.add(category)
                          : _categories.remove(category);
                    }),
                    onLeadChanged: (value) =>
                        setState(() => _leadMinutes = value),
                    onResultRemindersChanged: (value) =>
                        setState(() => _resultReminders = value),
                  ),
                ],
              ),
            ),
            _PageDots(count: _pageCount, index: _page),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: last
                        ? (_categories.isEmpty || _savingNotifications
                              ? null
                              : _enableNotifications)
                        : _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: AppColors.onAccent,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.mediumBorder,
                      ),
                    ),
                    child: Text(
                      last ? '알림 켜고 시작하기' : '다음',
                      style: AppType.headline,
                    ),
                  ),
                  if (last) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _finish,
                      child: Text(
                        '알림 없이 시작하기',
                        style: AppType.subhead.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      children: [
        Text(title, style: AppType.largeTitle.copyWith(color: AppColors.white)),
        const SizedBox(height: 10),
        Text(
          description,
          style: AppType.body.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 28),
        child,
      ],
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: '비아 포뮬러',
      description: 'F1 의 모든 세션을 한국시간으로.\n포뮬러 매거진 코리아가 만듭니다.',
      child: Column(
        children: const [
          _FeatureRow(
            icon: Icons.event_outlined,
            title: '한국시간 일정',
            description: '세션 시작 시각과 카운트다운을 KST 로 바로 보여줘요.',
          ),
          _FeatureRow(
            icon: Icons.sensors_rounded,
            title: '라이브 센터',
            description: '실시간 순위·트랙맵·팀 라디오, 중계 지연에 맞춰 보기까지.',
          ),
          _FeatureRow(
            icon: Icons.widgets_outlined,
            title: '홈 화면 위젯',
            description: '다음 세션과 순위, MY DRIVER 를 앱을 열지 않고 확인해요.',
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.tileSurface,
              borderRadius: AppRadius.mediumBorder,
            ),
            child: Icon(icon, size: 20, color: AppColors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppType.headline.copyWith(color: AppColors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppType.subhead.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PicksPage extends StatelessWidget {
  const _PicksPage({
    required this.picks,
    required this.onPickDriver,
    required this.onPickTeam,
  });

  final MyPicks picks;
  final VoidCallback onPickDriver;
  final VoidCallback onPickTeam;

  @override
  Widget build(BuildContext context) {
    final code = picks.driverCode;
    final teamKo = picks.teamKo;
    return _PageFrame(
      title: '누구를 응원하세요?',
      description: '고른 드라이버와 팀은 홈 위젯과 순위 화면에 먼저 보여요. 나중에 설정에서 바꿀 수 있어요.',
      child: Column(
        children: [
          _PickTile(
            key: const ValueKey('onboarding-pick-driver'),
            label: 'MY DRIVER',
            value: picks.hasDriver ? driverNameKo(code!, code) : null,
            accent: picks.hasDriver ? liveDriverAccent(code!) : null,
            onTap: onPickDriver,
          ),
          const SizedBox(height: 12),
          _PickTile(
            key: const ValueKey('onboarding-pick-team'),
            label: 'MY TEAM',
            value: picks.hasTeam ? teamKo : null,
            accent: picks.hasTeam ? getTeamColor(teamKo!) : null,
            onTap: onPickTeam,
          ),
        ],
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final String? value;
  final Color? accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final picked = value != null;
    return Material(
      color: AppColors.card,
      borderRadius: AppRadius.cardBorder,
      child: InkWell(
        borderRadius: AppRadius.cardBorder,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: accent ?? AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppType.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value ?? '선택하기',
                      style: AppType.headline.copyWith(
                        color: picked ? AppColors.white : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                picked ? Icons.check_circle_rounded : Icons.chevron_right,
                color: picked ? AppColors.white : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage({
    required this.categories,
    required this.leadMinutes,
    required this.resultReminders,
    required this.onCategoryChanged,
    required this.onLeadChanged,
    required this.onResultRemindersChanged,
  });

  final Set<SessionCategory> categories;
  final int leadMinutes;
  final bool resultReminders;
  final void Function(SessionCategory category, bool on) onCategoryChanged;
  final ValueChanged<int> onLeadChanged;
  final ValueChanged<bool> onResultRemindersChanged;

  static const Map<SessionCategory, String> _labels = {
    SessionCategory.practice: '프랙티스',
    SessionCategory.qualifying: '퀄리파잉',
    SessionCategory.sprint: '스프린트',
    SessionCategory.race: '레이스',
  };

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: '세션을 놓치지 않게',
      description: '유럽·미주 그랑프리는 대부분 새벽이에요. 고른 세션만 시작 전에 알려 드려요.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in _labels.entries)
                FilterChip(
                  label: Text(entry.value),
                  selected: categories.contains(entry.key),
                  onSelected: (on) => onCategoryChanged(entry.key, on),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '알림 시점',
            style: AppType.headline.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: [
                for (final minutes in notificationLeadMinuteOptions)
                  ButtonSegment<int>(
                    value: minutes,
                    label: Text(minutes == 60 ? '1시간 전' : '$minutes분 전'),
                  ),
              ],
              selected: {leadMinutes},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => onLeadChanged(selection.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '결과 알림도 받기',
              style: AppType.body.copyWith(color: AppColors.white),
            ),
            subtitle: Text(
              '세션이 끝나면 알려요. 순위는 알림에 넣지 않아요.',
              style: AppType.caption.copyWith(color: AppColors.textMuted),
            ),
            value: resultReminders,
            onChanged: onResultRemindersChanged,
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${index + 1} / $count 단계',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == index ? AppColors.white : AppColors.dotInactive,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}
