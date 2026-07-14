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
import '../widgets/app_card.dart';
import '../widgets/hero_card.dart';
import '../widgets/home_live_top_three_card.dart';
import '../widgets/home_quick_actions_card.dart';
import '../widgets/home_standings_card.dart';
import '../widgets/live_session_builder.dart';
import '../widgets/app_ui.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.nowOverride,
    this.liveSnapshotOverride,
    this.onOpenStandings,
    this.standingsRepository,
  });

  final DateTime? nowOverride;
  final LiveSessionSnapshot? liveSnapshotOverride;

  /// 순위 탭으로 전환(TOP 3 카드 탭). MainShell 이 연결한다.
  final VoidCallback? onOpenStandings;

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
    this.standingsRepository,
  });

  final DateTime? nowOverride;
  final LiveSessionSnapshot? liveSnapshotOverride;
  final VoidCallback? onOpenStandings;
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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          const AppPageHeader(
            title: '2026 시즌',
            trailing: _HomeSettingsButton(),
          ),
          const SizedBox(height: 16),
          // 라이브 Top 3 카드/히어로/주말 일정 모두 같은 스냅샷을 본다.
          LiveSessionBuilder(
            builder: (builderContext, snapshot, isStale) {
              final liveSnapshot = liveSnapshotOverride ?? snapshot;
              final liveStale = liveSnapshotOverride == null && isStale;
              final nextRace = _effectiveNextRace(now, liveSnapshot);
              final nextSession = getNextSession(nextRace, now);
              return Column(
                children: [
                  HomeLiveTopThreeCard(
                    snapshot: liveSnapshot,
                    isStale: liveStale,
                    now: now,
                    onTap: () =>
                        _openLiveRace(builderContext, liveSnapshot?.raceId),
                  ),
                  const SizedBox(height: 12),
                  // 다음 그랑프리 히어로 — 다음 세션 정보를 내부에 포함
                  _NextRaceCard(
                    race: nextRace,
                    session: nextSession,
                    now: now,
                    liveSnapshot: liveSnapshot,
                    // nowOverride(테스트) 주입 시 카운트다운 타이머를 멈춰
                    // 시각을 결정적으로 만든다.
                    ticking: nowOverride == null,
                  ),
                  // 주말 일정은 히어로 카드에 통합됨(별도 카드 제거).
                  // 챔피언십 TOP 3 — 순위 탭과 같은 데이터의 미리보기.
                  HomeStandingsCard(
                    repository: standingsRepository,
                    onOpenStandings: onOpenStandings,
                  ),
                  // 빠른 설정: 알림 + 위젯(메인 기능) 진입점.
                  const SizedBox(height: 12),
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

class _HomeSettingsButton extends StatelessWidget {
  const _HomeSettingsButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          );
        },
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(
            Icons.settings_outlined,
            size: 20,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}

class _NextRaceCard extends StatelessWidget {
  const _NextRaceCard({
    required this.race,
    required this.session,
    required this.now,
    required this.liveSnapshot,
    this.ticking = true,
  });

  final Race race;
  final RaceSession? session;
  final DateTime now;
  final LiveSessionSnapshot? liveSnapshot;

  /// false 면 카운트다운 타이머를 돌리지 않는다(nowOverride 주입 시 결정성).
  final bool ticking;

  @override
  Widget build(BuildContext context) {
    final status = getRaceDisplayStatus(race, now);
    // 웹 hero: 진행중이면 "진행중", 그 외에는 "다음 그랑프리"(취소는 별도 표기).
    final statusLabel = race.isCancelled
        ? '취소'
        : status == RaceStatus.inProgress
        ? '진행중'
        : '다음 그랑프리';

    // 히어로 v2(디자인 핸드오프 Home v2.dc.html 1a): 카운트다운이 주인공.
    // [뱃지·날짜범위 → GP명 → 서킷 → 카운트다운 3칸 + 다음 세션 타일 →
    //  세션 리스트(다음 세션 하이라이트/레이스 강조/완료 체크)]
    final boxedSession = session;

    return HeroCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => RaceDetailScreen(race: race)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 아이덴티티: 뱃지 + 날짜 범위 / GP명 / 서킷 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: _HeroBadge(label: statusLabel)),
                    const SizedBox(width: 8),
                    const Spacer(),
                    Text(
                      _heroDateRange(race),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.heroMeta,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final largeText =
                        MediaQuery.textScalerOf(context).scale(1) >= 1.25;
                    final displayName = largeText && constraints.maxWidth < 330
                        ? race.nameKo.replaceFirst('-', '-\n')
                        : race.nameKo;
                    return Text(
                      displayName,
                      semanticsLabel: race.nameKo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 30,
                        height: 1.1,
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 5),
                Text(
                  '${race.circuitKo} · ${race.cityKo}, ${race.countryKo}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.heroSubText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── 카운트다운 3칸 + 다음 세션 타일 (취소 GP 는 안내 텍스트) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: boxedSession == null
                ? Text(
                    race.cancelNote ?? '세션 정보가 아직 준비되지 않았습니다.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  )
                : _HeroCountdownRow(
                    race: race,
                    session: boxedSession,
                    now: now,
                    liveSnapshot: liveSnapshot,
                    ticking: ticking,
                  ),
          ),
          const SizedBox(height: 14),
          // ── 세션 리스트 (어두운 내부 컨테이너) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0x40000000), // black/25
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final s in race.sessions)
                    _HeroSessionRow(
                      race: race,
                      session: s,
                      now: now,
                      isNext: s.id == boxedSession?.id,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 히어로 상태 뱃지("다음 그랑프리"/"진행중"/"취소") — 레드 필 아웃라인.
class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.heroAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.heroAccent.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.heroAccent,
        ),
      ),
    );
  }
}

/// 카운트다운 3칸(DAYS/HRS/MIN) + 다음 세션 하이라이트 타일.
///
/// 타일은 기존 세션 박스의 상태 정책을 그대로 잇는다:
/// 라이브 스냅샷(이 GP + 활성) > 스케줄상 라이브 > 최근/다음 세션.
class _HeroCountdownRow extends StatefulWidget {
  const _HeroCountdownRow({
    required this.race,
    required this.session,
    required this.now,
    required this.liveSnapshot,
    required this.ticking,
  });

  final Race race;
  final RaceSession session;
  final DateTime now;
  final LiveSessionSnapshot? liveSnapshot;
  final bool ticking;

  @override
  State<_HeroCountdownRow> createState() => _HeroCountdownRowState();
}

class _HeroCountdownRowState extends State<_HeroCountdownRow> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = widget.now;
    if (widget.ticking) {
      // 표시 최소 단위가 분이므로 1분 주기면 충분하다.
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    }
  }

  @override
  void didUpdateWidget(covariant _HeroCountdownRow oldWidget) {
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
    final target = getSessionDate(widget.race, widget.session);
    // 시작이 지나면(라이브/직후) 0으로 클램프 — 상태는 타일이 표현한다.
    final diff = target.difference(_now);
    final clamped = diff.isNegative ? Duration.zero : diff;
    final days = clamped.inDays;
    final hours = clamped.inHours % 24;
    final minutes = clamped.inMinutes % 60;
    String pad(int v) => v.toString().padLeft(2, '0');

    final tile = _resolveTile();

    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.25;
        final compact = largeText || constraints.maxWidth < 320;
        final countdown = Row(
          children: [
            Expanded(
              child: _HeroCountSeg(value: pad(days), label: 'DAYS'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HeroCountSeg(value: pad(hours), label: 'HRS'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HeroCountSeg(value: pad(minutes), label: 'MIN'),
            ),
          ],
        );

        if (compact) {
          return Column(
            children: [
              countdown,
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: _HeroNextTile(label: tile.label, value: tile.value),
              ),
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 15, child: countdown),
              const SizedBox(width: 8),
              Expanded(
                flex: 7,
                child: _HeroNextTile(label: tile.label, value: tile.value),
              ),
            ],
          ),
        );
      },
    );
  }

  ({String label, String value}) _resolveTile() {
    final race = widget.race;
    final session = widget.session;

    // 이 GP의 활성 라이브 스냅샷이 있으면 '진행중'이 최우선.
    final snapshot = _matchingDisplayableSnapshot(
      widget.liveSnapshot,
      race,
      _now,
    );
    if (snapshot != null && isLiveSnapshotSessionActive(snapshot, _now)) {
      final mapped = liveRaceSessionForSnapshot(snapshot, race) ?? session;
      return (
        label: '진행중 · ${_snapshotSessionTitle(snapshot, mapped)}',
        value: 'LIVE',
      );
    }

    final status = getSessionStatus(race, session, _now);
    if (status == SessionStatus.live) {
      return (label: '진행중 · ${session.label}', value: 'LIVE');
    }

    final raceEnded = getRaceStatus(race, _now) == RaceStatus.ended;
    final prefix = raceEnded ? '최근 세션' : '다음 세션';
    // '금 20:30' — 날짜('7.17 금')에서 요일만 취해 시간과 붙인다.
    final parts = session.date.split(' ');
    final value = parts.length > 1
        ? '${parts.last} ${session.time}'
        : session.time;
    return (label: '$prefix · ${session.label}', value: value);
  }
}

/// 카운트다운 세그먼트 한 칸(숫자 + DAYS/HRS/MIN 라벨).
class _HeroCountSeg extends StatelessWidget {
  const _HeroCountSeg({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF), // white/5
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x12FFFFFF)), // white/7
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              height: 1.1,
              color: AppColors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.heroMeta,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// 다음/진행중/최근 세션 하이라이트 타일.
class _HeroNextTile extends StatelessWidget {
  const _HeroNextTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.heroAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.heroAccent.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.heroAccentBright,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// '7.17 – 7.19' 형태의 주말 날짜 범위(연도·앞자리 0 제거).
String _heroDateRange(Race race) {
  String short(String iso) {
    final parts = iso.split('-');
    if (parts.length < 3) return iso;
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (month == null || day == null) return iso;
    return '$month.$day';
  }

  return '${short(race.startDate)} – ${short(race.endDate)}';
}

/// 히어로 세션 리스트 한 줄(디자인 Home v2.dc.html 1a의 3상태 + 완료 상태).
/// - 다음 세션: 레드 배경 하이라이트 + 풀네임 + 흰색 800
/// - 레이스(미완료): 레드 도트 + 흰색 800
/// - 완료: 체크 아이콘 + 흐린 텍스트 (시안엔 없지만 주말 중반 UX 에 필요)
/// - 예정: 비활성 도트 + 목록 톤 텍스트
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
    final highlight = isNext && !isDone;
    final isRace = session.id == 'race' && !isDone;
    final emphasized = highlight || isRace;

    final nameColor = isDone
        ? AppColors.textEnded
        : emphasized
        ? AppColors.white
        : AppColors.heroRowText;
    final weight = emphasized ? FontWeight.w800 : FontWeight.w500;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.heroAccent.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 상태 도트: 완료는 체크, 다음/레이스는 레드, 예정은 비활성 톤.
          SizedBox(
            width: 11,
            child: Center(
              child: isDone
                  ? const Icon(
                      Icons.check,
                      size: 11,
                      color: AppColors.textEnded,
                    )
                  : Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: emphasized
                            ? AppColors.heroAccent
                            : AppColors.heroDotIdle,
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              // 다음 세션 행만 풀네임(예: '프리 프랙티스 1')으로 강조.
              highlight ? session.fullLabel : session.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.2,
                color: nameColor,
                fontWeight: weight,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text(
              session.date,
              maxLines: 1,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                color: isDone ? AppColors.textEnded : AppColors.heroDim,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            session.time,
            maxLines: 1,
            style: TextStyle(
              fontSize: 14,
              height: 1.2,
              color: nameColor,
              fontWeight: weight,
            ),
          ),
        ],
      ),
    );
  }
}

LiveSessionSnapshot? _matchingDisplayableSnapshot(
  LiveSessionSnapshot? snapshot,
  Race race,
  DateTime now,
) {
  if (snapshot == null || !isLiveSnapshotDisplayable(snapshot, now)) {
    return null;
  }
  return snapshot.raceId == race.id ? snapshot : null;
}

String _snapshotSessionTitle(
  LiveSessionSnapshot snapshot,
  RaceSession? mappedSession,
) {
  // 스냅샷의 영문 세션 이름(예: 'Sprint', 'Race')을 한글로 변환해 우선 사용한다.
  final label = liveSessionLabelKo(snapshot.sessionName, snapshot.sessionType);
  if (label != '세션') return label;

  // 스냅샷에 세션 정보가 없을 때만 스케줄에서 매핑된 한글 라벨로 보완한다.
  final mapped = mappedSession?.fullLabel.trim();
  return (mapped != null && mapped.isNotEmpty) ? mapped : '세션';
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
              child: _HomeSettingsButton(),
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
