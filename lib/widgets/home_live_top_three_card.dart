import 'package:flutter/material.dart';

import '../data/country_flags.dart';
import '../data/races.dart';
import '../models/live_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'flag_icon.dart';

/// 홈 라이브/최근 세션 Top 3 카드. 원래 웹 components/live/HomeLiveTopThreeCard.tsx
/// 이식이었고, 2026-10 디자인 정리로 홈 히어로와 같은 언어로 다시 그렸다:
/// 테두리·검은 하단 바·색 원형 순위 배지·10pt 대문자 라벨을 걷고, 레드는
/// 세션이 실제로 진행 중일 때의 LIVE 표시에만 쓴다.
///
/// snapshot 이 없거나 Top 3 가 3명 미만이면 아무것도 렌더하지 않는다(자리만 차지하지 않음).
class HomeLiveTopThreeCard extends StatelessWidget {
  const HomeLiveTopThreeCard({
    super.key,
    required this.snapshot,
    this.onTap,
    this.isStale = false,
    this.now,
  });

  final LiveSessionSnapshot? snapshot;
  final VoidCallback? onTap;

  /// 데이터 연결이 잠깐 흔들려 마지막 순위를 유지 중인 상태(3분 초과).
  final bool isStale;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    if (s == null || s.topThree.length < 3) {
      return const SizedBox.shrink();
    }
    final ended = s.isEnded && !isLiveSnapshotSessionActive(s, now);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.card,
        borderRadius: AppRadius.cardBorder,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(snapshot: s, ended: ended, isStale: isStale),
                const SizedBox(height: 10),
                _RaceTitle(snapshot: s),
                if (_lapLabel(s, ended) case final lap?) ...[
                  const SizedBox(height: 2),
                  Text(
                    lap,
                    style: AppType.subhead.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w400,
                      fontFeatures: AppType.tabular,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Divider(height: 0.5, thickness: 0.5, color: AppColors.border),
                const SizedBox(height: 4),
                for (var i = 0; i < 3; i++)
                  _TopThreeRow(
                    driver: s.topThree[i],
                    raceLike: s.isRaceOrSprint,
                  ),
                const SizedBox(height: 4),
                Divider(height: 0.5, thickness: 0.5, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '전체 순위 보기',
                          style: AppType.body.copyWith(color: AppColors.white),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: AppColors.textEnded,
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

  /// 레이스/스프린트 진행 중에만 "42 / 66랩". 종료 후엔 헤더가 '최종 결과'를
  /// 이미 말하므로 따로 적지 않는다.
  static String? _lapLabel(LiveSessionSnapshot s, bool ended) {
    if (ended || !s.isRaceOrSprint) return null;
    final lap = s.currentLap;
    final total = s.totalLaps;
    if (lap == null || total == null) return null;
    return '$lap / $total랩';
  }
}

/// [● LIVE · 레이스 ......... 업데이트 13:34 KST]
/// 종료 후: [최종 결과 · 프리 프랙티스 3 ......]
class _Header extends StatelessWidget {
  const _Header({
    required this.snapshot,
    required this.ended,
    required this.isStale,
  });

  final LiveSessionSnapshot snapshot;
  final bool ended;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    final muted = AppType.subhead.copyWith(color: AppColors.textMuted);
    final updated = isStale ? '업데이트 지연' : snapshot.updatedAtLabel;
    return Row(
      children: [
        if (!ended) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: AppColors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: AppType.subhead.copyWith(
              color: AppColors.red,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(' · ', style: muted),
        ] else
          Text('최종 결과 · ', style: muted),
        Expanded(
          child: Text(
            snapshot.sessionTitleKo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
        ),
        if (updated != null) ...[
          const SizedBox(width: 8),
          Text(
            updated,
            style: AppType.caption.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}

class _RaceTitle extends StatelessWidget {
  const _RaceTitle({required this.snapshot});

  final LiveSessionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    // raceId/raceName → races.dart 의 Race. 국기/한글 GP 이름을 여기서 함께 구한다.
    final race = resolveLiveRace(s.raceId, s.raceName);
    final flag =
        (race != null ? getCountryFlag(race.countryKo) : null) ??
        liveCountryFlag(s.raceId) ??
        s.countryFlag;
    final raceNameKo = race?.nameKo ?? s.raceName ?? 'Live Session';

    return Row(
      children: [
        // 매핑되는 국가는 벡터 국기, 라이브 피드가 준 이모지만 폴백.
        if (race != null) ...[
          FlagIcon(countryKo: race.countryKo, size: 18),
          const SizedBox(width: 8),
        ] else if (flag != null) ...[
          Text(flag, style: const TextStyle(fontSize: 18, height: 1)),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            raceNameKo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.headline.copyWith(
              fontSize: 18,
              color: AppColors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// 순위 숫자 · 팀 컬러 · 코드 · 이름 · 기록. 순위는 색 배지 대신 숫자만
/// 두고(홈 순위 섹션과 동일), 기록은 고정폭 숫자로 세로 정렬을 맞춘다.
class _TopThreeRow extends StatelessWidget {
  const _TopThreeRow({required this.driver, required this.raceLike});

  final LiveDriverPosition driver;
  final bool raceLike;

  @override
  Widget build(BuildContext context) {
    final time = driver.time(raceLike: raceLike);
    final numberStyle = AppType.body.copyWith(fontFeatures: AppType.tabular);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '${driver.position}',
              style: numberStyle.copyWith(color: AppColors.textMuted),
            ),
          ),
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: liveDriverAccent(driver.code),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text(
              driver.code,
              style: AppType.body.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              driver.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.body.copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            time,
            style: numberStyle.copyWith(
              color: time == '—' ? AppColors.textEnded : AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}
