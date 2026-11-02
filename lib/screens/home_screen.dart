import 'dart:async';

import 'package:flutter/material.dart';

import 'race_detail_screen.dart';
import 'settings_screen.dart';
import '../data/races.dart';
import '../models/live_session.dart';
import '../models/race.dart';
import '../models/race_session.dart';
import '../services/standings_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/flag_icon.dart';
import '../widgets/glass.dart';
import '../widgets/hero_card.dart';
import '../widgets/home_live_top_three_card.dart';
import '../widgets/home_quick_actions_card.dart';
import '../widgets/home_standings_card.dart';
import '../widgets/live_session_builder.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.nowOverride,
    this.liveSnapshotOverride,
    this.onOpenStandings,
    this.onOpenLiveCenter,
    this.standingsRepository,
  });

  final DateTime? nowOverride;
  final LiveSessionSnapshot? liveSnapshotOverride;

  /// 순위 탭으로 전환(TOP 3 카드 탭). MainShell 이 연결한다.
  final VoidCallback? onOpenStandings;

  /// 종료된 세션 카드에서 라이브 센터 탭으로 전환한다.
  final VoidCallback? onOpenLiveCenter;

  /// TOP 3 카드용 — 테스트/개발 주입 지점.
  final StandingsRepository? standingsRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: races.isEmpty
          ? const _EmptyHomeContent()
          : _SeasonHomeContent(
              nowOverride: nowOverride,
              liveSnapshotOverride: liveSnapshotOverride,
              onOpenStandings: onOpenStandings,
              onOpenLiveCenter: onOpenLiveCenter,
              standingsRepository: standingsRepository,
            ),
    );
  }
}

class _SeasonHomeContent extends StatelessWidget {
  const _SeasonHomeContent({
    this.nowOverride,
    this.liveSnapshotOverride,
    this.onOpenStandings,
    this.onOpenLiveCenter,
    this.standingsRepository,
  });

  final DateTime? nowOverride;
  final LiveSessionSnapshot? liveSnapshotOverride;
  final VoidCallback? onOpenStandings;
  final VoidCallback? onOpenLiveCenter;
  final StandingsRepository? standingsRepository;

  /// 스케줄 기준 다음 그랑프리. 다만 라이브 데이터가 레이스의 실제 종료를
  /// 알려주면(스케줄 종료 창보다 일찍 체커기), 그 시점부터 다음 그랑프리로
  /// 넘어간다 — 끝난 레이스를 '진행중'으로 계속 보여주지 않기 위함.
  Race _effectiveNextRace(DateTime now, LiveSessionSnapshot? liveSnapshot) {
    final race = getNextRace(now);
    if (liveSnapshot == null ||
        !liveSnapshotMarksRaceEnded(liveSnapshot, race, now)) {
      return race;
    }
    final weekendEnd = getRaceWeekendEndDate(race);
    if (weekendEnd == null) return race;
    return getNextRace(weekendEnd);
  }

  @override
  Widget build(BuildContext context) {
    final now = nowOverride ?? DateTime.now();

    return SafeArea(
      // 아래는 떠 있는 탭 바 밑으로 흐르게 둔다(여백은 pagePadding 이 준다).
      bottom: false,
      child: ListView(
        padding: AppLayout.pagePadding(context, top: 8, bottom: 32),
        children: [
          // 라지 타이틀 + 아이콘 두 개. 이전의 눈썹 문구('F1 관련 정보를 내
          // 손안에')는 정보가 없는 장식이라 뺐다.
          Row(
            children: [
              Expanded(
                child: Text(
                  'Via Formula',
                  style: AppType.largeTitle.copyWith(color: AppColors.white),
                ),
              ),
              const _HomeHeaderActions(),
            ],
          ),
          const SizedBox(height: 14),
          // 라이브 Top 3 카드/히어로/주말 일정 모두 같은 스냅샷을 본다.
          LiveSessionBuilder(
            builder: (builderContext, snapshot, isStale) {
              final liveSnapshot = liveSnapshotOverride ?? snapshot;
              final liveStale = liveSnapshotOverride == null && isStale;
              final nextRace = _effectiveNextRace(now, liveSnapshot);
              final nextSession = getNextSession(nextRace, now);
              // 라이브/최근 세션 카드가 실제로 그려지는지(=Top 3 확보) 미리 판단해
              // 히어로 카드와의 상단 간격을 조건부로만 넣는다(빈 카드면 여백 없음).
              final showLiveCard =
                  liveSnapshot != null && liveSnapshot.topThree.length >= 3;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _NextRaceCard(
                    race: nextRace,
                    session: nextSession,
                    now: now,
                    // nowOverride(테스트) 주입 시 카운트다운 타이머를 멈춰
                    // 시각을 결정적으로 만든다.
                    ticking: nowOverride == null,
                  ),
                  if (showLiveCard) const SizedBox(height: 12),
                  HomeLiveTopThreeCard(
                    snapshot: liveSnapshot,
                    isStale: liveStale,
                    now: now,
                    onTap: () {
                      final ended =
                          liveSnapshot != null &&
                          liveSnapshot.isEnded &&
                          !isLiveSnapshotSessionActive(liveSnapshot, now);
                      if (ended && onOpenLiveCenter != null) {
                        onOpenLiveCenter!();
                        return;
                      }
                      _openLiveRace(builderContext, liveSnapshot?.raceId);
                    },
                  ),
                  // 챔피언십 TOP 3 — 순위 탭과 같은 데이터의 미리보기.
                  HomeStandingsCard(
                    repository: standingsRepository,
                    onOpenStandings: onOpenStandings,
                  ),
                  // 빠른 설정: 알림 + 위젯(메인 기능) 진입점.
                  const SizedBox(height: 28),
                  const HomeQuickActionsCard(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HomeHeaderActions extends StatelessWidget {
  const _HomeHeaderActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HomeIconButton(
          key: const ValueKey('home-notification-button'),
          icon: Icons.notifications_outlined,
          tooltip: '알림 설정',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            );
          },
        ),
        _HomeIconButton(
          key: const ValueKey('home-settings-button'),
          icon: Icons.settings_outlined,
          tooltip: '설정',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            );
          },
        ),
      ],
    );
  }
}

/// 헤더 아이콘 버튼. 테두리 원 없이 글리프만 둔다(iOS 내비 바 버튼과 같은
/// 무게). 터치 영역은 44pt 를 유지한다.
class _HomeIconButton extends StatelessWidget {
  const _HomeIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 24, color: AppColors.white),
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
    );
  }
}

/// 다음 그랑프리 히어로.
///
/// 2026-10 디자인 정리: 한 카드에 레드가 다섯 군데(뱃지·테두리·하이라이트 행·
/// 점·다음 세션 박스) 쓰여 시선이 머물 곳이 없었다. 이제 주인공은 "다음 세션
/// 까지 남은 시간" 하나이고, 레드는 세션이 실제로 진행 중일 때만 쓴다.
/// [상태·날짜 캡션 → 국기+GP명 → 서킷 → 카운트다운 → 세션 목록]
class _NextRaceCard extends StatelessWidget {
  const _NextRaceCard({
    required this.race,
    required this.session,
    required this.now,
    this.ticking = true,
  });

  final Race race;
  final RaceSession? session;
  final DateTime now;

  /// false 면 카운트다운 타이머를 돌리지 않는다(nowOverride 주입 시 결정성).
  final bool ticking;

  @override
  Widget build(BuildContext context) {
    final status = getRaceDisplayStatus(race, now);
    // 주말 진행 중에는 '다음 그랑프리'가 틀린 말이라 '이번 주말'로 바꾼다.
    // '진행중'은 세션이 실제로 돌고 있을 때 카운트다운 자리에만 쓴다.
    final statusLabel = race.isCancelled
        ? '취소'
        : status == RaceStatus.inProgress
        ? '이번 주말'
        : '다음 그랑프리';
    final range = _weekendRangeLabel(race);
    final nextSession = session;
    // 국기 앰비언트 위라 회색(textMuted)은 배경색에 묻힌다 — 같은 위계를
    // 반투명 최상위 텍스트색으로 낸다(어떤 색 위에서도 명도 대비가 유지된다).
    final muted = heroSecondaryText();

    return HeroCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      ambientCountryKo: race.countryKo,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => RaceDetailScreen(race: race)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(statusLabel, style: AppType.subhead.copyWith(color: muted)),
              if (range.isNotEmpty)
                Flexible(
                  child: Text(
                    ' · $range',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.subhead.copyWith(color: muted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // GP명 앞에 국기. 이름이 2줄로 늘어날 수 있어 첫 줄에 맞춰 상단 정렬.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 10),
                child: FlagIcon(countryKo: race.countryKo, size: 22),
              ),
              Expanded(
                child: Text(
                  race.nameKo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.title.copyWith(color: AppColors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${race.circuitKo} · ${race.locationLabel}',
            // 한글은 글자 단위로 줄이 바뀌어 '스/페인'처럼 쪼개진다 — 한 줄로 자른다.
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.subhead.copyWith(
              color: muted,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),
          nextSession == null
              ? Text(
                  race.cancelNote ?? '세션 정보가 아직 준비되지 않았습니다.',
                  style: AppType.body.copyWith(color: muted),
                )
              : _HeroCountdown(
                  race: race,
                  session: nextSession,
                  now: now,
                  ticking: ticking,
                ),
          const SizedBox(height: 20),
          Divider(height: 0.5, thickness: 0.5, color: AppColors.border),
          const SizedBox(height: 6),
          for (final s in race.sessions)
            _HeroSessionRow(
              race: race,
              session: s,
              now: now,
              isNext: s.id == nextSession?.id,
            ),
        ],
      ),
    );
  }
}

/// "7월 17일 – 19일" / 달이 바뀌면 "7월 31일 – 8월 2일".
/// 이전엔 화면마다 '7.17 금', '2026-06-12 – 2026-06-14' 처럼 형식이 달랐다.
String _weekendRangeLabel(Race race) {
  final start = DateTime.tryParse(race.startDate);
  final end = DateTime.tryParse(race.endDate);
  if (start == null || end == null) return '';
  final head = '${start.month}월 ${start.day}일';
  if (start.month == end.month && start.day == end.day) return head;
  final tail = start.month == end.month
      ? '${end.day}일'
      : '${end.month}월 ${end.day}일';
  return '$head – $tail';
}

/// 카운트다운. "FP1 시작까지 · 금 20:30" 아래에 일·시간·분 글래스 타일 세 개를
/// 카드 폭 전체에 펼친다. 타일은 히어로 배경(국기 앰비언트)을 흐리게 비추고,
/// 숫자가 바뀔 때마다 아래에서 굴러 올라온다(사용자 피드백 2026-10: 초 단위는
/// 빼고 일·시간·분으로, 대신 밋밋하지 않게).
/// 세션이 이미 시작됐으면 숫자 대신 레드 점과 '진행중'을 보여준다.
class _HeroCountdown extends StatefulWidget {
  const _HeroCountdown({
    required this.race,
    required this.session,
    required this.now,
    required this.ticking,
  });

  final Race race;
  final RaceSession session;
  final DateTime now;
  final bool ticking;

  @override
  State<_HeroCountdown> createState() => _HeroCountdownState();
}

class _HeroCountdownState extends State<_HeroCountdown> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = widget.now;
    if (widget.ticking) {
      // 표시 단위는 분이지만 분이 바뀌는 순간을 놓치지 않게 1초마다 확인하고,
      // 실제로 분이 바뀔 때만 다시 그린다.
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final next = DateTime.now();
        if (!mounted) return;
        if (next.minute != _now.minute || next.hour != _now.hour) {
          setState(() => _now = next);
        } else {
          _now = next;
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant _HeroCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.now != widget.now) _now = widget.now;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = heroSecondaryText();
    final target = getSessionDate(widget.race, widget.session);
    final diff = target.difference(_now);
    final weekday = widget.session.date.split(' ').last;

    // 시작 시각이 지났으면(= 진행 중) 0 0 0 대신 상태를 말해 준다.
    if (diff.isNegative || diff == Duration.zero) {
      return GlassSurface(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            // 테스트(nowOverride)에선 반복 애니메이션을 멈춰 pumpAndSettle 이 끝나게 한다.
            _LiveDot(animate: widget.ticking),
            const SizedBox(width: 12),
            Text(
              '진행중',
              style: _countdownNumber.copyWith(
                fontSize: 30,
                color: AppColors.white,
              ),
            ),
            const Spacer(),
            Text(
              widget.session.label,
              style: AppType.headline.copyWith(color: muted),
            ),
          ],
        ),
      );
    }

    String two(int v) => v.toString().padLeft(2, '0');
    final parts = <(String, String)>[
      (two(diff.inDays), '일'),
      (two(diff.inHours % 24), '시간'),
      (two(diff.inMinutes % 60), '분'),
    ];

    return Column(
      key: const ValueKey('home-countdown'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // 아래 목록과 같은 짧은 이름 — 'FP1'과 '프리 프랙티스 1'이 섞이면
          // 다른 세션처럼 읽힌다.
          '${widget.session.label} 시작까지 · $weekday ${widget.session.time}',
          style: AppType.subhead.copyWith(color: muted),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (index, (value, unit)) in parts.indexed) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(
                child: _CountdownTile(value: value, unit: unit),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// 카운트다운 글래스 타일 한 칸: 굴러 올라오는 숫자 + 한글 단위.
class _CountdownTile extends StatelessWidget {
  const _CountdownTile({required this.value, required this.unit});

  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      child: Column(
        children: [
          ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                // 새 숫자는 아래에서 올라오고, 이전 숫자는 위로 빠진다.
                final incoming = child.key == ValueKey(value);
                final offset = Tween<Offset>(
                  begin: Offset(0, incoming ? 0.6 : -0.6),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offset, child: child),
                );
              },
              child: FittedBox(
                key: ValueKey(value),
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: _countdownNumber.copyWith(color: AppColors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(unit, style: AppType.caption.copyWith(color: heroSecondaryText())),
        ],
      ),
    );
  }
}

/// 진행 중 표시 — 레드 점이 천천히 숨쉬듯 번진다.
class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.animate});

  final bool animate;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final red = AppColors.red;
    return SizedBox.square(
      dimension: 22,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOut.transform(_controller.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 10 + 12 * t,
                height: 10 + 12 * t,
                decoration: BoxDecoration(
                  color: red.withValues(alpha: 0.45 * (1 - t)),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: red, shape: BoxShape.circle),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 카운트다운 숫자. 고정폭 숫자라 자리가 바뀌어도 폭이 흔들리지 않는다.
const TextStyle _countdownNumber = TextStyle(
  fontSize: 40,
  height: 1.1,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.8,
  fontFeatures: AppType.tabular,
);

/// 히어로 세션 목록 한 줄. 배경 하이라이트 없이 글자 무게와 명도로만 상태를
/// 나눈다.
/// - 진행 중: 레드 점 + 굵게 (레드는 이 경우에만)
/// - 다음 세션: 굵게, 최상위 텍스트색
/// - 예정: 기본 무게
/// - 종료: 가장 흐린 색
class _HeroSessionRow extends StatelessWidget {
  const _HeroSessionRow({
    required this.race,
    required this.session,
    required this.now,
    required this.isNext,
  });

  final Race race;
  final RaceSession session;
  final DateTime now;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final status = getSessionStatus(race, session, now);
    final isDone = status == SessionStatus.ended;
    final isLive = status == SessionStatus.live;
    final emphasized = isLive || (isNext && !isDone);

    final textColor = isDone
        ? AppColors.textEnded
        : emphasized
        ? AppColors.white
        : AppColors.scheduleText;
    final rowStyle = AppType.body.copyWith(
      color: textColor,
      fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
    );
    // '7.17 금' 에서 요일만 쓴다 — 날짜 범위는 위 캡션에 이미 있다.
    final weekday = session.date.split(' ').last;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          if (isLive) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              session.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: rowStyle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            weekday,
            style: AppType.body.copyWith(
              color: isDone ? AppColors.textEnded : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            session.time,
            style: rowStyle.copyWith(fontFeatures: AppType.tabular),
          ),
        ],
      ),
    );
  }
}

class _EmptyHomeContent extends StatelessWidget {
  const _EmptyHomeContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: _HomeHeaderActions(),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '시즌 데이터가 없습니다.',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '그랑프리 일정 데이터가 준비되면 홈 화면에 표시됩니다.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
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

// 라이브 카드 탭 → raceId 로 Race 를 찾아 상세로 이동. 못 찾으면 SnackBar 안내.
void _openLiveRace(BuildContext context, String? raceId) {
  final race = getRaceById(raceId);
  if (race == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('해당 그랑프리 정보를 찾을 수 없습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => RaceDetailScreen(race: race)));
}
