import 'dart:async';

import 'package:flutter/material.dart';

import '../data/races.dart';
import '../models/race.dart';
import '../screens/race_detail_screen.dart';
import '../services/race_results_repository.dart';
import 'race_result_classification_panel.dart';

/// 홈에서 가장 최근에 종료된 세션의 전체 분류표를 보여준다.
class HomeRecentResultCard extends StatefulWidget {
  const HomeRecentResultCard({
    super.key,
    this.repository,
    this.topPadding = 12,
  });

  final RaceResultsRepository? repository;
  final double topPadding;

  @override
  State<HomeRecentResultCard> createState() => _HomeRecentResultCardState();
}

class _HomeRecentResultCardState extends State<HomeRecentResultCard> {
  LatestRaceResult? _latest;
  Race? _race;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final repository = widget.repository ?? const HttpRaceResultsRepository();
    LatestRaceResult? latest;
    try {
      latest = await repository.fetchLatest();
    } catch (_) {
      return;
    }
    if (latest == null || !mounted) return;

    final race = getRaceById(latest.raceId);
    if (race == null) return;
    setState(() {
      _latest = latest;
      _race = race;
    });
  }

  void _openDetail() {
    final race = _race;
    if (race == null) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RaceDetailScreen(race: race)));
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latest;
    final race = _race;
    if (latest == null || race == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: widget.topPadding),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openDetail,
        child: RaceResultClassificationPanel(
          results: latest.data.entries,
          title:
              '최근 세션 결과 (${race.nameKo} '
              '${raceSessionTypeLabel(latest.sessionType)})',
          showDriverCount: false,
          // 연습/퀄리 세션은 행별 랩타임 표기(레이스류만 갭 기반).
          gapBased:
              latest.sessionType == 'RACE' || latest.sessionType == 'SPRINT',
        ),
      ),
    );
  }
}
