import 'dart:async';

import 'package:flutter/material.dart';

import '../data/races.dart';
import '../models/live_session.dart';
import '../models/race_session.dart';
import '../services/live_session_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/classification_panel_parts.dart';
import '../widgets/live_session_builder.dart';
import '../widgets/app_ui.dart';

class LiveCenterScreen extends StatelessWidget {
  const LiveCenterScreen({super.key, this.snapshotOverride, this.nowOverride});

  final LiveSessionSnapshot? snapshotOverride;
  final DateTime? nowOverride;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LiveSessionBuilder(
          latestSession: true,
          builder: (context, snapshot, isStale) {
            final value = snapshotOverride ?? snapshot;
            return RefreshIndicator(
              color: AppColors.red,
              backgroundColor: AppColors.card,
              onRefresh: liveSessionController.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  const AppPageHeader(
                    title: '라이브 센터',
                    description: '실시간 순위와 세션 상황을 한곳에서 확인하세요.',
                  ),
                  const SizedBox(height: 16),
                  if (value == null)
                    _OfflineCenter(now: nowOverride ?? DateTime.now())
                  else
                    _LiveContent(snapshot: value, isStale: isStale),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OfflineCenter extends StatelessWidget {
  const _OfflineCenter({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final race = getNextRace(now);
    final session = getNextSession(race, now);
    // 비라이브에도 라이브 때 나타날 카드들을 빈 상태(안내 문구 + '—')로
    // 유지한다 — 처음 들어온 사용자가 "세션 중에 여기서 뭘 보게 되는지"를
    // 화면 구조만으로 알 수 있게(숨기면 결과 다시보기 화면처럼 보인다).
    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const _StatusPill(label: '다음 라이브', color: AppColors.blueSoft),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${race.nameKo} · ${session?.fullLabel ?? '일정 준비 중'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (session != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${session.date} ${session.time} KST',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.schedule, color: AppColors.textMuted, size: 18),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            // stretch: 레이스 컨트롤처럼 Row/Expanded 없는 섹션도 카드 폭을
            // 가득 채워야 제목·본문이 다른 섹션과 좌측 정렬로 맞는다.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TimingPreviewCard(session: session),
              const Divider(height: 1, color: AppColors.rowBorder),
              const _RaceControlPreviewCard(),
              const Divider(height: 1, color: AppColors.rowBorder),
              const _WeatherPreviewCard(),
            ],
          ),
        ),
      ],
    );
  }
}

/// 비라이브용 실시간 순위 자리 카드 — 라이브 때와 같은 헤더에 안내만 채운다.
class _TimingPreviewCard extends StatelessWidget {
  const _TimingPreviewCard({this.session});

  final RaceSession? session;

  @override
  Widget build(BuildContext context) {
    final startLabel = session == null
        ? null
        : '${session!.date} ${session!.time} 세션 시작과 함께 표시됩니다.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '실시간 순위',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                'TIME / GAP',
                style: const TextStyle(
                  color: AppColors.faint,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
          child: Text(
            '전체 드라이버 순위와 랩타임·타이어·섹터가 실시간으로 올라옵니다.'
            '${startLabel == null ? '' : '\n$startLabel'}',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// 비라이브용 트랙 & 날씨 자리 카드 — 메트릭 틀을 '—'로 유지.
class _WeatherPreviewCard extends StatelessWidget {
  const _WeatherPreviewCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '트랙 & 날씨',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              _Metric(label: '대기', value: '—'),
              _Metric(label: '트랙', value: '—'),
              _Metric(label: '습도', value: '—'),
              _Metric(label: '바람', value: '—'),
            ],
          ),
        ],
      ),
    );
  }
}

/// 비라이브용 레이스 컨트롤 자리 카드.
class _RaceControlPreviewCard extends StatelessWidget {
  const _RaceControlPreviewCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '레이스 컨트롤',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 12),
          Text(
            '세이프티카, 플래그 등 스튜어드의 메시지가 실시간으로 표시됩니다.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveContent extends StatelessWidget {
  const _LiveContent({required this.snapshot, required this.isStale});

  final LiveSessionSnapshot snapshot;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SessionHeader(snapshot: snapshot, isStale: isStale),
        const SizedBox(height: 12),
        _TimingCard(snapshot: snapshot),
        const SizedBox(height: 12),
        _RaceControlCard(messages: snapshot.raceControlMessages),
        if (snapshot.weather != null) ...[
          const SizedBox(height: 12),
          _WeatherCard(weather: snapshot.weather!),
        ],
      ],
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.snapshot, required this.isStale});

  final LiveSessionSnapshot snapshot;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    final track =
        snapshot.trackStatusMessage ?? _trackStatusLabel(snapshot.trackStatus);
    final (statusLabel, statusColor) = switch (snapshot.status) {
      LiveSessionStatus.live => ('LIVE', AppColors.red),
      LiveSessionStatus.ended => ('최종 결과', AppColors.muted),
      LiveSessionStatus.inactive => ('세션 준비', AppColors.blueSoft),
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusPill(label: statusLabel, color: statusColor),
              if (isStale) ...[
                const SizedBox(width: 8),
                const _StatusPill(
                  label: '업데이트 지연',
                  color: AppColors.warningAmber,
                ),
              ],
              const Spacer(),
              if (snapshot.updatedAtLabel != null)
                Text(
                  snapshot.updatedAtLabel!,
                  style: const TextStyle(
                    color: AppColors.faint,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            // 피드의 영문 GP명 대신 한글 이름(races.dart 매핑)을 우선 사용.
            resolveLiveRace(snapshot.raceId, snapshot.raceName)?.nameKo ??
                snapshot.raceName ??
                'F1 라이브',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            snapshot.sessionTitleKo,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (snapshot.showLap)
                _Metric(
                  label: 'LAP',
                  value: '${snapshot.currentLap} / ${snapshot.totalLaps}',
                ),
              if (snapshot.remainingTime != null)
                _RemainingMetric(
                  remaining: snapshot.remainingTime!,
                  stopped: snapshot.clockStopped || snapshot.isEnded,
                ),
              _Metric(
                label: '트랙 상태',
                value: track,
                valueColor: _trackStatusColor(snapshot.trackStatus),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// '남은 시간' 로컬 티커 — 서버 값은 스냅샷 시점 기준이라 그대로 두면 멈춰
/// 보인다. 수신 시점부터 1초씩 로컬로 감산하고, 새 스냅샷이 오면 그 값으로
/// 재동기화한다. 시계 정지(레드 플래그 등, clockStopped) 중에는 멈춘다.
class _RemainingMetric extends StatefulWidget {
  const _RemainingMetric({required this.remaining, required this.stopped});

  final String remaining;
  final bool stopped;

  @override
  State<_RemainingMetric> createState() => _RemainingMetricState();
}

class _RemainingMetricState extends State<_RemainingMetric> {
  Timer? _timer;
  int _baseSeconds = -1; // -1 = 파싱 불가(원본 그대로 표시)
  int _segmentCount = 2;
  DateTime _receivedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _sync();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _RemainingMetric oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remaining != widget.remaining ||
        oldWidget.stopped != widget.stopped) {
      _sync();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _sync() {
    _receivedAt = DateTime.now();
    final parts = widget.remaining
        .split(':')
        .map((part) => int.tryParse(part.trim()))
        .toList();
    if (parts.isEmpty || parts.any((value) => value == null)) {
      _baseSeconds = -1;
      return;
    }
    var seconds = 0;
    for (final part in parts) {
      seconds = seconds * 60 + part!;
    }
    _baseSeconds = seconds;
    _segmentCount = parts.length;
  }

  String _display() {
    if (_baseSeconds < 0) return widget.remaining;
    var seconds = _baseSeconds;
    if (!widget.stopped) {
      seconds -= DateTime.now().difference(_receivedAt).inSeconds;
    }
    if (seconds < 0) seconds = 0;
    String pad(int value) => value.toString().padLeft(2, '0');
    final h = seconds ~/ 3600;
    final m = (seconds ~/ 60) % 60;
    final s = seconds % 60;
    return _segmentCount >= 3
        ? '${pad(h)}:${pad(m)}:${pad(s)}'
        : '${pad(h * 60 + m)}:${pad(s)}';
  }

  @override
  Widget build(BuildContext context) {
    return _Metric(label: '남은 시간', value: _display());
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.faint,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? AppColors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// 라이브 보드 탭 — 랩타임 / 섹터 / 타이어 관점을 전환한다.
enum _BoardTab { lap, sector, tire }

class _TimingCard extends StatefulWidget {
  const _TimingCard({required this.snapshot});

  final LiveSessionSnapshot snapshot;

  @override
  State<_TimingCard> createState() => _TimingCardState();
}

class _TimingCardState extends State<_TimingCard> {
  _BoardTab _tab = _BoardTab.lap;

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final drivers = snapshot.classification.isNotEmpty
        ? snapshot.classification
        : snapshot.topThree;
    // 22명 전부 펼치면 탭이 너무 길어진다 — Top 3만 상시, 나머지는 결과
    // 패널과 같은 접기/펼치기(ClassificationExpander)로 감춘다.
    final topThree = drivers.take(3).toList();
    final remaining = drivers.skip(3).toList();
    final raceLike = snapshot.isRaceOrSprint;
    final headerLabel = switch (_tab) {
      _BoardTab.lap => raceLike ? 'INTERVAL' : 'BEST LAP',
      _BoardTab.sector => 'SECTOR TIME',
      _BoardTab.tire => null,
    };
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '실시간 순위',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (headerLabel != null)
                  Text(
                    headerLabel,
                    style: const TextStyle(
                      color: AppColors.faint,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _BoardTabs(
              tab: _tab,
              onChanged: (tab) => setState(() => _tab = tab),
            ),
          ),
          if (drivers.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 18),
              child: Text(
                '타이밍 데이터 수신 대기 중',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            )
          else ...[
            for (final driver in topThree)
              _DriverRow(driver: driver, raceLike: raceLike, tab: _tab),
            if (remaining.isNotEmpty)
              ClassificationExpander(
                accent: snapshot.isEnded
                    ? AppColors.nameMuted
                    : AppColors.redSoft,
                startPosition: remaining.first.position,
                endPosition: remaining.last.position,
                count: remaining.length,
                rows: [
                  for (final driver in remaining)
                    _DriverRow(driver: driver, raceLike: raceLike, tab: _tab),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

/// LAP | SECTOR | TIRE 세그먼트 탭.
class _BoardTabs extends StatelessWidget {
  const _BoardTabs({required this.tab, required this.onChanged});

  final _BoardTab tab;
  final ValueChanged<_BoardTab> onChanged;

  static const Map<_BoardTab, String> _labels = {
    _BoardTab.lap: 'LAP',
    _BoardTab.sector: 'SECTOR',
    _BoardTab.tire: 'TIRE',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.black20,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final value in _BoardTab.values)
            Expanded(
              child: Material(
                color: value == tab
                    ? AppColors.resultChipSurface
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onChanged(value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Center(
                      child: Text(
                        _labels[value]!,
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w800,
                          color: value == tab
                              ? AppColors.white
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DriverRow extends StatelessWidget {
  const _DriverRow({
    required this.driver,
    required this.raceLike,
    required this.tab,
  });

  final LiveDriverPosition driver;
  final bool raceLike;
  final _BoardTab tab;

  /// 보조 정보(랩 수·PIT) 스타일.
  static const TextStyle _metaStyle = TextStyle(
    color: AppColors.nameMuted,
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle _tinyLabelStyle = TextStyle(
    color: AppColors.faint,
    fontSize: 8,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
  );

  /// 최고기록 플래그 → 색: 'ob' 퍼플(전체) / 'pb' 그린(개인) / 기본.
  static Color _flagColor(String? flag, {Color fallback = AppColors.slate300}) {
    if (flag == 'ob') return AppColors.timingPurple;
    if (flag == 'pb') return AppColors.greenSoft;
    return fallback;
  }

  /// 섹터 상세 — 서버가 구버전이면 sector1~3 값으로 폴백.
  List<LiveSectorDetail> get _sectors {
    final details = driver.sectorDetails;
    if (details.any((s) => s.value != null || s.segments.isNotEmpty)) {
      return details;
    }
    return [
      LiveSectorDetail(value: driver.sector1),
      LiveSectorDetail(value: driver.sector2),
      LiveSectorDetail(value: driver.sector3),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rowBorder)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 25,
            child: Text(
              '${driver.position}',
              style: const TextStyle(
                color: AppColors.slate300,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: liveDriverAccent(driver.code),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text(
              driver.code,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(child: _content()),
          const SizedBox(width: 8),
          _trailing(),
        ],
      ),
    );
  }

  Widget _content() {
    return switch (tab) {
      _BoardTab.lap => _lapContent(),
      _BoardTab.sector => _sectorContent(),
      _BoardTab.tire => _tireContent(),
    };
  }

  /// LAP 탭은 랩 기록만 보인다. 섹터 값은 SECTOR 탭에만 두어 중복을 없앤다.
  Widget _lapContent() {
    final best = raceLike ? driver.bestLapTime : driver.displayTime;
    final bestColor = best == null
        ? AppColors.slate300
        : driver.bestLapIsOverall
        ? AppColors.timingPurple
        : AppColors.greenSoft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (raceLike) ...[
              _lapCluster(
                'LAST',
                driver.lastLapTime,
                _flagColor(driver.lastLapFlag),
              ),
              const SizedBox(width: 14),
              _lapCluster('BEST', best, bestColor),
            ] else ...[
              _lapCluster('BEST', best, bestColor),
              const SizedBox(width: 14),
              _lapCluster(
                'LAST',
                driver.lastLapTime,
                _flagColor(driver.lastLapFlag),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _lapCluster(String label, String? value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _tinyLabelStyle),
        const SizedBox(height: 1),
        Text(
          value ?? '—',
          style: TextStyle(
            color: value == null ? AppColors.faint : color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  /// SECTOR 탭: 현재 섹터(플래그 색) 위, 미니섹터와 개인 베스트를 아래에 둔다.
  Widget _sectorContent() {
    final sectors = _sectors;
    return Row(
      children: [
        for (var i = 0; i < sectors.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('S${i + 1} ', style: _tinyLabelStyle),
                  Text(
                    sectors[i].value ?? '—',
                    style: TextStyle(
                      color: sectors[i].value == null
                          ? AppColors.faint
                          : _flagColor(sectors[i].flag),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              if (sectors[i].segments.isNotEmpty) ...[
                _MiniSectorBar(segments: sectors[i].segments),
                const SizedBox(height: 3),
              ],
              Text(
                (i < driver.bestSectors.length
                        ? driver.bestSectors[i]
                        : null) ??
                    '—',
                style: const TextStyle(
                  color: AppColors.faint,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// TIRE 탭: 현재 타이어 + PIT 횟수 + 스틴트 히스토리 바.
  Widget _tireContent() {
    final stints = driver.stints
        .where((s) => s.compound != null || (s.laps ?? 0) > 0)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (driver.compound != null) ...[
              _TyreBadge(compound: driver.compound!),
              if (driver.tyreAge != null) ...[
                const SizedBox(width: 5),
                Text('${driver.tyreAge}랩', style: _metaStyle),
              ],
            ],
            if (driver.pitStops != null) ...[
              if (driver.compound != null) const SizedBox(width: 12),
              Text('PIT ${driver.pitStops}', style: _metaStyle),
            ],
            if (driver.compound == null && driver.pitStops == null)
              const Text('타이어 데이터 수신 대기', style: _tinyLabelStyle),
          ],
        ),
        if (stints.isNotEmpty) ...[
          const SizedBox(height: 6),
          _StintBar(stints: stints),
        ],
      ],
    );
  }

  Widget _trailing() {
    // PIT/OUT 상태가 최우선. 그 외 LAP 탭 레이스는 INTERVAL,
    // 나머지 탭/세션에서는 비워 본문에 폭을 양보한다.
    final String text;
    if (driver.retired) {
      text = 'OUT';
    } else if (driver.inPit) {
      text = 'PIT';
    } else if (tab == _BoardTab.lap && raceLike) {
      text = driver.gap(raceLike: true);
    } else {
      return const SizedBox.shrink();
    }
    return Text(
      text,
      style: TextStyle(
        color: driver.inPit || driver.retired
            ? AppColors.redSoft
            : AppColors.slate300,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/// 미니섹터 상태 코드 → 색 점 바.
/// 2048 완주(옐로) / 2049 개인최고(그린) / 2051 전체최고(퍼플) / 2064 핏(블루).
class _MiniSectorBar extends StatelessWidget {
  const _MiniSectorBar({required this.segments});

  final List<int> segments;

  static Color _segmentColor(int code) {
    switch (code) {
      case 2051:
        return AppColors.timingPurple;
      case 2049:
        return AppColors.greenSoft;
      case 2064:
        return AppColors.blueSoft;
      case 2048:
        return AppColors.flagYellow;
      default:
        return AppColors.dotInactive; // 미주행 구간
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final code in segments)
          Container(
            width: 3.5,
            height: 6,
            margin: const EdgeInsets.only(right: 1.5),
            decoration: BoxDecoration(
              color: _segmentColor(code),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }
}

/// 스틴트 히스토리 바 — 컴파운드 색 구간을 사용 랩 수 비율로 나눈다.
class _StintBar extends StatelessWidget {
  const _StintBar({required this.stints});

  final List<LiveStint> stints;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < stints.length; i++)
          Expanded(
            flex: (stints[i].laps ?? 1).clamp(1, 999),
            child: Container(
              height: 7,
              margin: EdgeInsets.only(right: i == stints.length - 1 ? 0 : 2),
              decoration: BoxDecoration(
                color: _compoundColor(stints[i].compound ?? ''),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}

/// 타이어 컴파운드 배지 — 컴파운드 색 링 + 약어(S/M/H/I/W).
class _TyreBadge extends StatelessWidget {
  const _TyreBadge({required this.compound});

  final String compound;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 17,
      height: 17,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _compoundColor(compound), width: 2),
      ),
      child: Text(
        _compoundShort(compound),
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 9,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// 컴파운드 표준 의미색(소프트 레드 · 미디엄 옐로 · 하드 화이트 계열 ·
/// 인터미디엇 그린 · 웻 블루). 노란색 금지 규칙의 예외 — 깃발처럼 F1
/// 도메인 의미색이라 다른 색으로 바꾸면 오히려 오독된다.
Color _compoundColor(String value) => switch (value.trim().toUpperCase()) {
  'SOFT' => AppColors.red,
  'MEDIUM' => AppColors.flagYellow,
  'HARD' => AppColors.slate300,
  'INTERMEDIATE' => AppColors.greenSoft,
  'WET' => AppColors.blueSoft,
  _ => AppColors.textMuted,
};

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.weather});

  final LiveWeather weather;

  @override
  Widget build(BuildContext context) {
    String number(double? value, String suffix) =>
        value == null ? '—' : '${value.toStringAsFixed(1)}$suffix';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '트랙 & 날씨',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Metric(label: '대기', value: number(weather.airTemperature, '°')),
              _Metric(
                label: '트랙',
                value: number(weather.trackTemperature, '°'),
              ),
              _Metric(label: '습도', value: number(weather.humidity, '%')),
              _Metric(label: '바람', value: number(weather.windSpeed, 'm/s')),
            ],
          ),
          if (weather.rainfall == true) ...[
            const SizedBox(height: 12),
            const _StatusPill(label: '강수 감지', color: AppColors.blueSoft),
          ],
        ],
      ),
    );
  }
}

class _RaceControlCard extends StatelessWidget {
  const _RaceControlCard({required this.messages});

  final List<LiveRaceControlMessage> messages;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '레이스 컨트롤',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (messages.isEmpty)
            const Text(
              '새로운 레이스 컨트롤 메시지가 없습니다.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            )
          else ...[
            // 세션 내내 쌓이는 목록이라 최신 3개만 상시, 이전은 접어둔다.
            for (final message in messages.take(3))
              _ControlMessage(message: message),
            if (messages.length > 3)
              _MessageExpander(
                count: messages.length - 3,
                rows: [
                  for (final message in messages.skip(3))
                    _ControlMessage(message: message),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

/// 레이스 컨트롤 "이전 메시지" 접기/펼치기(순위 확장 UI와 같은 시각 언어).
class _MessageExpander extends StatefulWidget {
  const _MessageExpander({required this.count, required this.rows});

  final int count;
  final List<Widget> rows;

  @override
  State<_MessageExpander> createState() => _MessageExpanderState();
}

class _MessageExpanderState extends State<_MessageExpander> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.rowBorder)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _expanded ? '메시지 접기' : '이전 메시지 보기',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.redSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_expanded)
                      Text(
                        '+ ${widget.count}개 더',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _expanded ? '↑' : '↓',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.redSoft,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...widget.rows,
      ],
    );
  }
}

class _ControlMessage extends StatelessWidget {
  const _ControlMessage({required this.message});

  final LiveRaceControlMessage message;

  @override
  Widget build(BuildContext context) {
    final local = message.timestamp?.toLocal();
    final time = local == null
        ? null
        : '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rowBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 30,
            decoration: BoxDecoration(
              color: _messageColor(message),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.message,
                  style: const TextStyle(
                    color: AppColors.slate300,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (time != null || message.category != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [?time, ?message.category].join(' · '),
                    style: const TextStyle(
                      color: AppColors.faint,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

String _compoundShort(String value) {
  switch (value.trim().toUpperCase()) {
    case 'SOFT':
      return 'S';
    case 'MEDIUM':
      return 'M';
    case 'HARD':
      return 'H';
    case 'INTERMEDIATE':
      return 'I';
    case 'WET':
      return 'W';
    default:
      return value.toUpperCase();
  }
}

String _trackStatusLabel(String? value) {
  switch (value?.trim().toUpperCase()) {
    case '1':
    case 'ALL_CLEAR':
    case 'GREEN':
      return 'GREEN';
    case '2':
    case 'YELLOW':
      return 'YELLOW';
    case '4':
    case 'SC':
    case 'SAFETY_CAR':
      return 'SAFETY CAR';
    case '5':
    case 'RED':
      return 'RED FLAG';
    case '6':
    case 'VSC':
      return 'VSC';
    case '7':
    case 'VSC_ENDING':
      return 'VSC ENDING';
    default:
      return value ?? '—';
  }
}

Color _trackStatusColor(String? value) {
  final label = _trackStatusLabel(value);
  if (label.contains('RED')) return AppColors.redSoft;
  if (label.contains('YELLOW') ||
      label.contains('SC') ||
      label.contains('VSC')) {
    return AppColors.flagYellow;
  }
  if (label == 'GREEN') return AppColors.greenSoft;
  return AppColors.white;
}

Color _messageColor(LiveRaceControlMessage message) {
  final text =
      '${message.flag ?? ''} ${message.category ?? ''} ${message.message}'
          .toUpperCase();
  if (text.contains('RED')) return AppColors.red;
  if (text.contains('YELLOW') ||
      text.contains('SAFETY CAR') ||
      text.contains('VSC')) {
    return AppColors.flagYellow;
  }
  if (text.contains('GREEN')) return AppColors.greenSoft;
  return AppColors.blueSoft;
}
