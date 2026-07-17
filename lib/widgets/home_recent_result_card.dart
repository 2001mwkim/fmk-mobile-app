import 'dart:async';

import 'package:flutter/material.dart';

import '../data/races.dart';
import '../models/live_session.dart';
import '../models/race.dart';
import '../screens/race_detail_screen.dart';
import '../services/race_results_repository.dart';
import 'live_last_session_panel.dart';
import 'race_result_classification_panel.dart';

/// 가장 최근에 종료된 세션의 전체 분류표를 보여준다.
///
/// 소스 우선순위: ① 라이브 파생 직전 세션(collector lastSession — 세션 종료
/// 직후부터 신선) → ② F1DB 공식 결과(그랑프리 종료 후 발행, 같은 세션을
/// 커버하게 되면 공식 데이터가 더 풍부하므로 교체).
class HomeRecentResultCard extends StatefulWidget {
  const HomeRecentResultCard({
    super.key,
    this.repository,
    this.topPadding = 12,
    this.lastSession,
  });

  final RaceResultsRepository? repository;
  final double topPadding;

  /// 라이브 파생 직전 세션 결과(라이브 센터가 컨트롤러에서 전달).
  final LiveLastSession? lastSession;

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
    // 라이브 파생 직전 세션이 공식 결과보다 최신이면 그쪽을 먼저 보여준다.
    final live = widget.lastSession;
    if (live != null && !_officialCoversLive(live, _latest)) {
      return Padding(
        padding: EdgeInsets.only(top: widget.topPadding),
        child: LiveLastSessionPanel(last: live),
      );
    }

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

/// F1DB 공식 결과가 라이브 파생 직전 세션과 같은 세션까지 커버하는가.
/// 커버하면 공식 데이터(총시간·포인트 포함)가 더 풍부하므로 그쪽을 쓴다.
bool _officialCoversLive(LiveLastSession live, LatestRaceResult? official) {
  if (official == null) return false;
  // 다른 GP(또는 매핑 실패)면 라이브 쪽이 현재 주말 — 라이브 우선.
  if (live.raceId == null || official.raceId != live.raceId) return false;
  final liveOrder = _sessionOrder(_liveSessionEnum(live) ?? 'RACE');
  return _sessionOrder(official.sessionType) >= liveOrder;
}

/// 라이브 세션 텍스트 → 서버 결과 계약의 sessionType 열거값.
String? _liveSessionEnum(LiveLastSession live) {
  final text = '${live.sessionType ?? ''} ${live.sessionName ?? ''}'
      .toLowerCase();
  if (text.contains('sprint')) {
    return (text.contains('qual') || text.contains('shootout'))
        ? 'SPRINT_QUALIFYING'
        : 'SPRINT';
  }
  if (text.contains('qual')) return 'QUALIFYING';
  if (text.contains('race')) return 'RACE';
  if (text.contains('practice')) {
    if (text.contains('3')) return 'FP3';
    if (text.contains('2')) return 'FP2';
    return 'FP1';
  }
  return null;
}

/// 주말 진행 순서(값이 클수록 나중 세션).
int _sessionOrder(String type) => switch (type) {
  'FP1' => 0,
  'FP2' => 1,
  'FP3' => 2,
  'SPRINT_QUALIFYING' => 3,
  'SPRINT' => 4,
  'QUALIFYING' => 5,
  'RACE' => 6,
  _ => -1,
};
