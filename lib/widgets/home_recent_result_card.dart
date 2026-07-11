import 'package:flutter/material.dart';

import '../data/races.dart';
import '../data/team_colors.dart';
import '../models/race.dart';
import '../models/race_result.dart';
import '../screens/race_detail_screen.dart';
import '../services/race_results_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';

/// 홈 하단 "최근 레이스 결과" 카드 — 가장 최근 결과가 있는 GP 의 포디움(1~3위).
///
/// 디자인: 핸드오프 recent_race_result_card.html(1b '팀컬러 엣지' 안) 재구현.
/// - 헤더 좌측: 타이틀(레드) + "그랑프리명 · 공식/잠정 결과" 서브타이틀
/// - 헤더 우측: 원형 chevron 버튼(›) — 하단 '전체 보기' 버튼을 대체
/// - 행 3개: 균등한 타일, 왼쪽 4px 팀컬러 세로 바, 순위/이름/팀명
/// 컨테이너는 홈의 다른 카드와 통일된 [AppCard](라운딩 16)를 쓰고, 색은
/// [AppColors] 토큰으로 매핑했다(화면에 hex 직접 금지 컨벤션).
///
/// 데이터는 상세 화면과 같은 /api/race-results 를 재사용한다(fetchLatest).
/// 결과가 없거나(시즌 개막 전/서버 미배포) API 가 실패하면 **아무것도
/// 렌더하지 않는다** — 홈에 빈 상태 카드를 추가하지 않는 정책.
class HomeRecentResultCard extends StatefulWidget {
  const HomeRecentResultCard({super.key, this.repository});

  /// 테스트/개발용 주입 지점. 기본값은 실서버(/api/race-results).
  final RaceResultsRepository? repository;

  @override
  State<HomeRecentResultCard> createState() => _HomeRecentResultCardState();
}

class _HomeRecentResultCardState extends State<HomeRecentResultCard> {
  LatestRaceResult? _latest;
  Race? _race;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = widget.repository ?? const HttpRaceResultsRepository();
    LatestRaceResult? latest;
    try {
      latest = await repository.fetchLatest();
    } catch (_) {
      return; // 실패 시 카드 미표시(홈은 기존 구성 유지).
    }
    if (latest == null || !mounted) return;

    // raceId → 앱 레이스(이름/상세 이동용). 모르는 id 면 표시하지 않는다.
    final race = getRaceById(latest.raceId);
    if (race == null) return;
    setState(() {
      _latest = latest;
      _race = race;
    });
  }

  void _openDetail(BuildContext context) {
    final race = _race;
    if (race == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RaceDetailScreen(race: race)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latest;
    final race = _race;
    if (latest == null || race == null) return const SizedBox.shrink();

    final podium = latest.data.entries.take(3).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        onTap: () => _openDetail(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- 헤더: 타이틀/서브타이틀 + 원형 chevron(상세 이동) ----
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 홈 리디자인(home_screen_2a): 타이틀은 흰색 — 레드는
                      // 히어로 뱃지/레이스 강조 전용으로 아껴 쓴다.
                      const Text(
                        '최근 레이스 결과',
                        style: TextStyle(
                          fontSize: 17,
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${race.nameKo} · ${latest.data.isOfficial ? '공식 결과' : '잠정 결과'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.heroSub,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // 28px 원형 버튼 + 44px 히트 영역(접근성) — 디자인 요구사항.
                SizedBox(
                  width: 44,
                  height: 44,
                  child: InkResponse(
                    key: const Key('recent-result-chevron'),
                    onTap: () => _openDetail(context),
                    radius: 24,
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: AppColors.resultChipSurface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: AppColors.heroSub,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ---- 포디움 3행: 팀컬러 엣지 균등 타일 ----
            for (var i = 0; i < podium.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _podiumRow(podium[i]),
            ],
          ],
        ),
      ),
    );
  }

  /// 한 행: [4px 팀컬러 바] 순위 · 드라이버명 · 팀명.
  Widget _podiumRow(RaceResultEntry entry) {
    final teamColor = getTeamColor(entry.teamKo);
    final isFirst = entry.position == 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: AppColors.resultRowSurface),
          ),
          // 왼쪽 엣지: 행 전체 높이의 4px 팀컬러 세로 바.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ColoredBox(color: teamColor),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 13, 16, 13),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '${entry.position}',
                    style: TextStyle(
                      fontSize: 22,
                      height: 1,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w700,
                      // 1위만 흰색으로 강조, 2·3위는 보조 톤.
                      color: isFirst ? AppColors.white : AppColors.heroSub,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.driverKo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isFirst ? FontWeight.w700 : FontWeight.w500,
                      color: isFirst ? AppColors.white : AppColors.textSoft,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  entry.teamKo,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _teamTextColor(entry.teamKo),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 팀명 텍스트 색: 팀컬러를 다크 배경에서 읽히도록 밝기 보정.
  /// 어두운 팀컬러(페라리 레드 등)는 밝히고, 이미 밝은 색(메르세데스 티일 등)은
  /// 살짝 톤다운한다 — 디자인 핸드오프의 #E8556F/#4fd8c2 근사.
  Color _teamTextColor(String teamKo) {
    final base = getTeamColor(teamKo);
    return isLightTeamColor(teamKo)
        ? Color.lerp(base, AppColors.black, 0.15)!
        : Color.lerp(base, AppColors.white, 0.35)!;
  }
}
