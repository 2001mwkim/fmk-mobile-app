import 'package:flutter/material.dart';

import '../data/races.dart';
import '../data/team_colors.dart';
import '../models/race.dart';
import '../models/race_result.dart';
import '../screens/race_detail_screen.dart';
import '../services/race_results_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';

/// 홈 하단 "최근 레이스 결과" 카드 — 가장 최근 결과가 있는 GP 의 Top 3 요약.
///
/// 데이터는 상세 화면과 같은 /api/race-results 를 재사용한다(fetchLatest).
/// 결과가 없거나(시즌 개막 전/서버 미배포) API 가 실패하면 **아무것도
/// 렌더하지 않는다** — 홈에 빈 상태 카드를 추가하지 않는 정책.
/// '전체 보기'/카드 탭 → 해당 GP 상세 화면(전체 순위)으로 이동.
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

    final topThree = latest.data.entries.take(3).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        onTap: () => _openDetail(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 섹션 제목 + 결과 상태
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '최근 레이스 결과',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  latest.data.isOfficial ? '공식 결과' : '잠정 결과',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              race.nameKo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.heroSub,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            for (final entry in topThree) _podiumRow(entry),
            const SizedBox(height: 4),
            // 전체 보기 → GP 상세(전체 순위 패널)
            const Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '전체 보기',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.redSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 11, color: AppColors.redSoft),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Top 3 한 줄: 순위 · 드라이버(한글) · 팀(한글). 팀 컬러 바로 포인트.
  Widget _podiumRow(RaceResultEntry entry) {
    final teamColor = getTeamColor(
      entry.teamKo,
    ).withValues(alpha: isLightTeamColor(entry.teamKo) ? 0.7 : 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              '${entry.position}',
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Pretendard',
                // 노란색 금지 규칙 — P1 강조는 레드.
                color: entry.position == 1 ? AppColors.red : AppColors.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            width: 3,
            height: 14,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: teamColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text(
              entry.driverKo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            entry.teamKo,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.nameMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}