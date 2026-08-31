import 'package:flutter/material.dart';

import '../data/drivers.dart';
import '../data/standings.dart' as static_standings;
import '../data/team_colors.dart';
import '../data/teams.dart';
import '../models/standing.dart';
import '../services/fmk_home_widget_bridge.dart';
import '../services/my_picks_controller.dart';
import '../services/standings_repository.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';
import 'app_chip.dart';

/// 설정 > MY PICKS 카드: 내 드라이버 / 내 팀 두 타일.
///
/// 타일은 홈 위젯(MY DRIVER / MY TEAM)의 축소 미리보기처럼 그린다 —
/// 킥커 + 큰 TLA(또는 팀 약어) + 영문 이름 + 순위/포인트, 팀 컬러는 약어 옆
/// 얇은 바로만(앱 전체의 심플한 톤 유지). 선택은 바텀시트 그리드에서 한다.
class MyPicksCard extends StatefulWidget {
  const MyPicksCard({
    super.key,
    this.controller,
    this.standingsRepository,
    this.onChanged,
  });

  /// 테스트 주입 지점(기본은 앱 전역 [myPicksController]).
  final MyPicksController? controller;

  /// 순위(포인트·순위 표기)용 — 실패하면 번들 정적 순위로 폴백.
  final StandingsRepository? standingsRepository;

  /// 선택이 바뀐 뒤 호출(기본은 홈 위젯 갱신). 테스트에서 네이티브 호출을 막는다.
  final Future<void> Function()? onChanged;

  @override
  State<MyPicksCard> createState() => _MyPicksCardState();
}

class _MyPicksCardState extends State<MyPicksCard> {
  MyPicksController get _controller => widget.controller ?? myPicksController;

  List<DriverStanding> _drivers = static_standings.driverStandings;
  List<ConstructorStanding> _teams = static_standings.constructorStandings;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onPicksChanged);
    _controller.load();
    _loadStandings();
  }

  @override
  void dispose() {
    _controller.removeListener(_onPicksChanged);
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
      // 정적 순위 유지.
    }
  }

  Future<void> _afterChange(String message) async {
    await (widget.onChanged ?? FmkHomeWidgetBridge.update)();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  Future<void> _pickDriver() async {
    final current = _controller.picks.driverCode;
    final result = await showModalBottomSheet<MyPickResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MyDriverPickerSheet(current: current, drivers: _drivers),
    );
    if (result == null || !mounted) return;
    await _controller.saveDriver(result.clear ? null : result.value);
    final code = result.value;
    await _afterChange(
      result.clear
          ? 'MY DRIVER 를 해제했어요.'
          : 'MY DRIVER · ${driverNameKo(code!, code)} 으로 설정했어요. 홈 위젯에 반영됩니다.',
    );
  }

  Future<void> _pickTeam() async {
    final current = _controller.picks.teamKo;
    final result = await showModalBottomSheet<MyPickResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          MyTeamPickerSheet(current: current, teams: _teams, drivers: _drivers),
    );
    if (result == null || !mounted) return;
    await _controller.saveTeam(result.clear ? null : result.value);
    await _afterChange(
      result.clear
          ? 'MY TEAM 을 해제했어요.'
          : 'MY TEAM · ${result.value} 으로 설정했어요. 홈 위젯에 반영됩니다.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final picks = _controller.picks;
    final payload = buildFmkMyPicksPayload(
      picks: picks,
      driverStandings: _drivers,
      constructorStandings: _teams,
    );
    final driver = payload.driver;
    final team = payload.team;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: _Header(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: _PickTile(
                    key: const ValueKey('my-pick-driver'),
                    kicker: 'MY DRIVER',
                    accent: driver == null ? null : Color(driver.teamColor),
                    headline: driver?.code,
                    subline: driver?.nameEn,
                    statLine: driver == null
                        ? null
                        : _statLine(
                            driver.found,
                            driver.position,
                            driver.points,
                          ),
                    emptyLabel: '드라이버 선택',
                    onTap: _pickDriver,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickTile(
                    key: const ValueKey('my-pick-team'),
                    kicker: 'MY TEAM',
                    accent: team == null ? null : Color(team.teamColor),
                    // 위젯과 동일하게 팀은 영문 풀네임(대문자, 최대 2줄).
                    headline: team == null ? null : _teamHeadline(team),
                    headlineLines: 2,
                    headlineSize: 18,
                    subline: team?.drivers.map((d) => d.code).join(' · '),
                    statLine: team == null
                        ? null
                        : _statLine(team.found, team.position, team.points),
                    emptyLabel: '팀 선택',
                    onTap: _pickTeam,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 팀 타일 헤드라인 — 위젯과 동일하게 영문 풀네임 대문자(없으면 약어).
  static String _teamHeadline(FmkMyTeamWidgetData t) =>
      (t.teamEn.isEmpty ? t.code : t.teamEn).toUpperCase();

  static String _statLine(bool found, int position, String points) {
    if (!found || position <= 0) return '순위 집계 전';
    return points.isEmpty ? 'P$position' : 'P$position · $points PTS';
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '내 드라이버 · 내 팀',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(width: 12),
            AppChip(label: '홈 위젯', variant: AppChipVariant.neutral),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '응원하는 드라이버와 팀을 고르면 홈 위젯(MY DRIVER · MY TEAM)에 순위·포인트가 팀 컬러로 표시됩니다.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.muted,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// 위젯 미리보기 타일. [accent] 가 null 이면 미설정(빈 상태) 스타일.
/// 장식 없이 앱 공통 톤(타일 표면 + 팀 컬러 바)만 쓴다.
class _PickTile extends StatelessWidget {
  const _PickTile({
    super.key,
    required this.kicker,
    required this.accent,
    required this.headline,
    required this.subline,
    required this.statLine,
    required this.emptyLabel,
    required this.onTap,
    this.headlineLines = 1,
    this.headlineSize = 26,
  });

  final String kicker;
  final Color? accent;
  final String? headline;

  /// 헤드라인 최대 줄 수/크기 — 드라이버 TLA 는 1줄 26, 팀 풀네임은 2줄 18.
  final int headlineLines;
  final double headlineSize;
  final String? subline;
  final String? statLine;
  final String emptyLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSet = accent != null && headline != null;
    final glow = accent ?? AppColors.muted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          height: 128,
          decoration: BoxDecoration(
            color: AppColors.tileSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.faintBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              kicker,
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w800,
                                color: isSet ? AppColors.redSoft : AppColors.muted,
                              ),
                            ),
                          ),
                          Icon(
                            isSet ? Icons.edit_outlined : Icons.add_circle_outline,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (isSet) ...[
                        // 팀 컬러는 약어 옆 얇은 바로만(순위 탭/위젯과 같은 문법).
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 바는 텍스트 높이(1~2줄)를 따라 늘어난다.
                              Container(
                                width: 3,
                                margin: EdgeInsets.symmetric(
                                  vertical: headlineSize * 0.1,
                                ),
                                decoration: BoxDecoration(
                                  color: glow,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  headline!,
                                  maxLines: headlineLines,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: headlineSize,
                                    height: 1.05,
                                    letterSpacing: -0.5,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          subline ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.nameMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statLine ?? '',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate300,
                          ),
                        ),
                      ] else ...[
                        Text(
                          emptyLabel,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '탭해서 고르기',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 선택기 결과: [clear] 면 해제, 아니면 [value](드라이버 코드 또는 teamKo).
class MyPickResult {
  const MyPickResult.select(String this.value) : clear = false;
  const MyPickResult.clear() : value = null, clear = true;

  final String? value;
  final bool clear;
}

/// MY DRIVER 선택 바텀시트 — 순위순 2열 그리드.
class MyDriverPickerSheet extends StatelessWidget {
  const MyDriverPickerSheet({
    super.key,
    required this.current,
    required this.drivers,
  });

  final String? current;
  final List<DriverStanding> drivers;

  @override
  Widget build(BuildContext context) {
    // 순위 데이터에 없는(코드 매핑만 있는) 드라이버도 뒤에 붙여 고를 수 있게.
    final seen = <String>{};
    final entries = <_DriverEntry>[];
    for (final d in drivers) {
      final code = driverCodeByNameKo[d.driverKo];
      if (code == null) continue;
      seen.add(code);
      entries.add(_DriverEntry(code: code, standing: d));
    }
    for (final code in driverNameKoByCode.keys) {
      if (!seen.contains(code)) entries.add(_DriverEntry(code: code));
    }

    return _PickerScaffold(
      title: 'MY DRIVER',
      subtitle: '응원하는 드라이버를 고르세요',
      canClear: current != null,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final e = entries[index];
          final s = e.standing;
          final teamKo = s?.teamKo ?? '';
          final accent = s != null
              ? getTeamColor(teamKo)
              : liveDriverAccent(e.code);
          return _PickGridCard(
            key: ValueKey('pick-driver-${e.code}'),
            accent: accent,
            headline: e.code,
            title: driverNameKo(e.code, s?.driverKo ?? e.code),
            subtitle: s == null
                ? driverNameEn(e.code, '')
                : teamNameEn(teamKo, s.teamEn),
            stat: s == null ? '—' : 'P${s.position} · ${_pts(s.points)}',
            selected: current == e.code,
            onTap: () =>
                Navigator.of(context).pop(MyPickResult.select(e.code)),
          );
        },
      ),
    );
  }
}

class _DriverEntry {
  const _DriverEntry({required this.code, this.standing});
  final String code;
  final DriverStanding? standing;
}

/// MY TEAM 선택 바텀시트 — 순위순 2열 그리드.
class MyTeamPickerSheet extends StatelessWidget {
  const MyTeamPickerSheet({
    super.key,
    required this.current,
    required this.teams,
    required this.drivers,
  });

  final String? current;
  final List<ConstructorStanding> teams;
  final List<DriverStanding> drivers;

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final entries = <_TeamEntry>[];
    for (final c in teams) {
      seen.add(c.teamKo);
      entries.add(_TeamEntry(teamKo: c.teamKo, standing: c));
    }
    for (final teamKo in teamKoList) {
      if (!seen.contains(teamKo)) entries.add(_TeamEntry(teamKo: teamKo));
    }

    return _PickerScaffold(
      title: 'MY TEAM',
      subtitle: '응원하는 팀을 고르세요',
      canClear: current != null,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final e = entries[index];
          final s = e.standing;
          // 소속 드라이버 코드(순위순) — 카드 서브라인.
          final members = [
            for (final d in drivers)
              if (d.teamKo == e.teamKo) driverCodeByNameKo[d.driverKo] ?? '',
          ].where((c) => c.isNotEmpty).take(2).join(' · ');
          return _PickGridCard(
            key: ValueKey('pick-team-${e.teamKo}'),
            accent: getTeamColor(e.teamKo),
            headline: teamCode(e.teamKo, fallbackEn: s?.teamEn ?? ''),
            title: e.teamKo,
            subtitle: members.isEmpty
                ? teamNameEn(e.teamKo, s?.teamEn ?? '')
                : members,
            stat: s == null ? '—' : 'P${s.position} · ${_pts(s.points)}',
            selected: current == e.teamKo,
            onTap: () =>
                Navigator.of(context).pop(MyPickResult.select(e.teamKo)),
          );
        },
      ),
    );
  }
}

class _TeamEntry {
  const _TeamEntry({required this.teamKo, this.standing});
  final String teamKo;
  final ConstructorStanding? standing;
}

String _pts(num points) {
  final text = (points is int || points == points.roundToDouble())
      ? points.toInt().toString()
      : points.toString();
  return '${text}pt';
}

/// 선택기 공통 틀: 상단 타이틀/부제 + (선택 시) 해제 버튼 + 본문.
class _PickerScaffold extends StatelessWidget {
  const _PickerScaffold({
    required this.title,
    required this.subtitle,
    required this.canClear,
    required this.child,
  });

  final String title;
  final String subtitle;
  final bool canClear;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.8,
                            color: AppColors.redSoft,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canClear)
                    TextButton(
                      key: const ValueKey('my-pick-clear'),
                      onPressed: () =>
                          Navigator.of(context).pop(const MyPickResult.clear()),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('선택 해제'),
                    ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.divider),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

/// 그리드 한 칸: 팀 컬러 바 + 큰 약어, 이름, 순위/포인트(선택 시 팀 컬러 테두리).
class _PickGridCard extends StatelessWidget {
  const _PickGridCard({
    super.key,
    required this.accent,
    required this.headline,
    required this.title,
    required this.subtitle,
    required this.stat,
    required this.selected,
    required this.onTap,
  });

  final Color accent;
  final String headline;
  final String title;
  final String subtitle;
  final String stat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.tileSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent : AppColors.faintBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                if (selected)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 12,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 18,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            headline,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 22,
                              height: 1,
                              letterSpacing: -0.4,
                              fontWeight: FontWeight.w900,
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSoft,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            stat,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slate300,
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
        ),
      ),
    );
  }
}
