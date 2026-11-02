import 'package:flutter/material.dart';

import '../data/standings.dart' as static_standings;
import '../data/team_colors.dart';
import '../models/standing.dart';
import '../services/standings_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'hero_card.dart' show heroSecondaryText;

/// 홈 "챔피언십 순위" 섹션. 순위 탭과 같은 데이터(정적 초기값 →
/// 서버 갱신)를 드라이버·컨스트럭터 Top 3 씩 위아래로 보여주고, 탭하면
/// 순위 탭으로 이동한다. 홈은 공간이 좁아 순위 변동(▲▼)은 생략한다
/// (전체 변동은 순위 탭에서 확인).
class HomeStandingsCard extends StatefulWidget {
  const HomeStandingsCard({super.key, this.repository, this.onOpenStandings});

  /// 테스트/개발용 주입 지점. 기본값은 실서버(/api/standings).
  final StandingsRepository? repository;

  /// 순위 탭으로 전환하는 콜백(MainShell 이 연결). 없으면 탭해도 무동작.
  final VoidCallback? onOpenStandings;

  @override
  State<HomeStandingsCard> createState() => _HomeStandingsCardState();
}

class _HomeStandingsCardState extends State<HomeStandingsCard> {
  // 첫 프레임은 번들 정적 순위로 그리고(로딩 화면 없음), 서버 응답이 오면
  // 최신 순위로 교체한다. 서버 실패 시 정적 데이터가 그대로 남는다.
  List<DriverStanding> _drivers = static_standings.driverStandings;
  List<ConstructorStanding> _constructors =
      static_standings.constructorStandings;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final repository = widget.repository ?? const HttpStandingsRepository();
    final snapshot = await repository.fetchLatest();
    if (snapshot == null || !mounted) return;
    setState(() {
      _drivers = snapshot.driverStandings;
      _constructors = snapshot.constructorStandings;
    });
  }

  @override
  Widget build(BuildContext context) {
    final drivers = _drivers.take(3).toList();
    final constructors = _constructors.take(3).toList();
    if (drivers.isEmpty && constructors.isEmpty) {
      return const SizedBox.shrink();
    }

    // 섹션 제목은 카드 밖에 둔다(iOS 그룹 목록 방식) — 카드 안 제목 + 카드
    // 테두리는 상자 안에 상자를 하나 더 만드는 셈이었다.
    // 두 열 배치는 큰 글씨·좁은 폭에서 이름이 잘려 위아래 두 묶음으로 바꿨다.
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpenStandings,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      '챔피언십 순위',
                      style: AppType.title.copyWith(
                        fontSize: 20,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  Text(
                    '전체 보기',
                    style: AppType.subhead.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
            _GlowCard(
              // 선두 팀 색을 카드 위쪽에 은은하게 번지게 한다(히어로의 국기
              // 앰비언트와 같은 언어). 순위가 바뀌면 카드 색도 따라 바뀐다.
              glow: getTeamColor(
                drivers.isNotEmpty
                    ? drivers.first.teamKo
                    : constructors.first.teamKo,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StandingsGroup(
                    label: '드라이버',
                    rows: [
                      for (final d in drivers)
                        _RowData(
                          position: d.position,
                          teamKo: d.teamKo,
                          title: d.driverKo,
                          points: d.points,
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _StandingsGroup(
                    label: '컨스트럭터',
                    rows: [
                      for (final c in constructors)
                        _RowData(
                          position: c.position,
                          teamKo: c.teamKo,
                          title: c.teamKo,
                          points: c.points,
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

class _StandingsGroup extends StatelessWidget {
  const _StandingsGroup({required this.label, required this.rows});

  final String label;
  final List<_RowData> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // 행 안쪽 글자(순위 숫자)와 왼쪽 선을 맞춘다.
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            label,
            style: AppType.subhead.copyWith(color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 8),
        for (final (index, row) in rows.indexed) ...[
          if (index > 0) const SizedBox(height: 6),
          _StandingRow(
            data: row,
            leaderPoints: rows.isEmpty ? 0 : rows.first.points,
          ),
        ],
      ],
    );
  }
}

/// 순위 한 줄. 행 뒤를 팀 색 막대가 선두 대비 포인트 비율만큼 채워서
/// 순위표가 그대로 격차 그래프가 된다(사용자 피드백 2026-10: 밋밋하다).
/// 2·3위는 선두와의 차이를 포인트 앞에 작게 붙인다.
/// 이전의 색 원형 배지(1위 빨강·2위 회색·3위 주황)는 규칙이 읽히지 않아 뺐다.
class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.data, required this.leaderPoints});

  final _RowData data;
  final num leaderPoints;

  @override
  Widget build(BuildContext context) {
    final teamColor = getTeamColor(data.teamKo);
    final share = leaderPoints <= 0
        ? 0.0
        : (data.points / leaderPoints).clamp(0.0, 1.0).toDouble();
    final gap = leaderPoints - data.points;
    final numberStyle = AppType.body.copyWith(fontFeatures: AppType.tabular);
    const radius = BorderRadius.all(Radius.circular(10));

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          // 바탕(빈 칸) — 막대가 얼마나 찼는지 비교 기준이 된다.
          Positioned.fill(
            child: ColoredBox(color: AppColors.white.withValues(alpha: 0.04)),
          ),
          // 처음 그려질 때·순위가 갱신될 때 막대가 왼쪽에서 차오른다.
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: share),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: child,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    colors: [
                      teamColor.withValues(alpha: 0.42),
                      teamColor.withValues(alpha: 0.16),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '${data.position}',
                    style: numberStyle.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body.copyWith(
                      color: AppColors.white,
                      fontWeight: data.position == 1
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (gap > 0) ...[
                  Text(
                    '-${_formatPoints(gap)}',
                    style: AppType.caption.copyWith(
                      color: heroSecondaryText(),
                      fontFeatures: AppType.tabular,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _formatPoints(data.points),
                  style: numberStyle.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 3),
                // 포인트 단위는 F1 관례 표기 PTS(사용자 결정, 2026-10).
                Text(
                  'PTS',
                  style: AppType.caption.copyWith(color: heroSecondaryText()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 위쪽에 [glow] 색이 은은하게 번지는 카드 표면.
class _GlowCard extends StatelessWidget {
  const _GlowCard({required this.glow, required this.child});

  final Color glow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.cardBorder,
        gradient: RadialGradient(
          center: const Alignment(-0.9, -1.1),
          radius: 1.3,
          colors: [
            Color.alphaBlend(glow.withValues(alpha: 0.22), AppColors.card),
            AppColors.card,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: child,
      ),
    );
  }
}

class _RowData {
  const _RowData({
    required this.position,
    required this.teamKo,
    required this.title,
    required this.points,
  });

  final int position;
  final String teamKo;
  final String title;
  final num points;
}

String _formatPoints(num points) {
  if (points is int || points == points.roundToDouble()) {
    return points.toInt().toString();
  }
  return points.toString();
}
