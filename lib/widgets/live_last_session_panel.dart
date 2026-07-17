import 'package:flutter/material.dart';

import '../data/drivers.dart';
import '../data/races.dart';
import '../models/live_session.dart';
import '../screens/race_detail_screen.dart';
import '../theme/app_colors.dart';
import 'classification_panel_parts.dart';

/// 라이브 파생 "직전 세션 결과" 패널.
///
/// F1DB 공식 결과는 그랑프리 종료 후에나 발행되므로, 주말 중에는 collector 가
/// 보관한 세션 종료 순간의 최종 순위(LiveLastSession)를 결과 패널과 같은
/// 시각 언어로 보여준다. 팀명 매핑이 없어 서브 라벨은 드라이버 코드,
/// 액센트는 라이브 보드와 같은 드라이버 컬러를 쓴다.
class LiveLastSessionPanel extends StatelessWidget {
  const LiveLastSessionPanel({super.key, required this.last});

  final LiveLastSession last;

  @override
  Widget build(BuildContext context) {
    final race = getRaceById(last.raceId);
    final raceLike = last.isRaceOrSprint;
    final drivers = [...last.classification]
      ..sort((a, b) => a.position.compareTo(b.position));
    final topThree = drivers.take(3).toList();
    final remaining = drivers.skip(3).toList();
    final gpName = race?.nameKo ?? last.raceName ?? '';
    final title = '최근 세션 결과 ($gpName ${last.sessionTitleKo})'.trim();

    final panel = ClassificationPanelShell(
      borderColor: AppColors.border,
      children: [
        ClassificationHeaderContainer(
          emphasized: false,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '세션 종료 기준',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.nameMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        ClassificationColumnHeader(timeLabel: raceLike ? 'GAP' : 'BEST'),
        for (final driver in topThree) _row(driver, raceLike),
        if (remaining.isNotEmpty)
          ClassificationExpander(
            accent: AppColors.nameMuted,
            startPosition: remaining.first.position,
            endPosition: remaining.last.position,
            count: remaining.length,
            rows: [for (final driver in remaining) _row(driver, raceLike)],
          ),
      ],
    );

    if (race == null) return panel;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => RaceDetailScreen(race: race))),
      child: panel,
    );
  }

  Widget _row(LiveDriverPosition driver, bool raceLike) {
    // 레이스류는 선두와의 갭, 연습/퀄리는 베스트 랩(라이브 표시 정책과 동일 계열).
    final trailing = raceLike
        ? (driver.gapToLeader ?? '—')
        : (driver.displayTime ?? driver.lapTime ?? driver.bestLapTime ?? '—');
    return ClassificationRow(
      position: driver.position,
      positionLabel: '${driver.position}',
      accentColor: liveDriverAccent(driver.code),
      name: driverNameKo(driver.code, driver.displayName),
      subtitle: driver.code,
      trailing: trailing,
    );
  }
}
