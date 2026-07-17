import 'package:flutter/material.dart';

import '../data/races.dart';
import '../models/live_session.dart';
import '../models/race_session.dart';
import '../services/live_session_controller.dart';
import '../services/race_results_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/home_recent_result_card.dart';
import '../widgets/live_session_builder.dart';
import '../widgets/app_ui.dart';

class LiveCenterScreen extends StatelessWidget {
  const LiveCenterScreen({
    super.key,
    this.snapshotOverride,
    this.nowOverride,
    this.resultsRepository,
  });

  final LiveSessionSnapshot? snapshotOverride;
  final DateTime? nowOverride;
  final RaceResultsRepository? resultsRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LiveSessionBuilder(
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
                    _OfflineCenter(
                      now: nowOverride ?? DateTime.now(),
                      resultsRepository: resultsRepository,
                    )
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
  const _OfflineCenter({required this.now, this.resultsRepository});

  final DateTime now;
  final RaceResultsRepository? resultsRepository;

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
              const _WeatherPreviewCard(),
              const Divider(height: 1, color: AppColors.rowBorder),
              const _RaceControlPreviewCard(),
            ],
          ),
        ),
        HomeRecentResultCard(repository: resultsRepository, topPadding: 16),
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
        if (snapshot.weather != null) ...[
          const SizedBox(height: 12),
          _WeatherCard(weather: snapshot.weather!),
        ],
        const SizedBox(height: 12),
        _TimingCard(snapshot: snapshot),
        const SizedBox(height: 12),
        _RaceControlCard(messages: snapshot.raceControlMessages),
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusPill(
                label: snapshot.isEnded ? '최종 결과' : 'LIVE',
                color: snapshot.isEnded ? AppColors.muted : AppColors.red,
              ),
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
                _Metric(label: '남은 시간', value: snapshot.remainingTime!),
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

class _TimingCard extends StatelessWidget {
  const _TimingCard({required this.snapshot});

  final LiveSessionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final drivers = snapshot.classification.isNotEmpty
        ? snapshot.classification
        : snapshot.topThree;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
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
                  snapshot.gapColumnLabel,
                  style: const TextStyle(
                    color: AppColors.faint,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
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
          else
            for (final driver in drivers)
              _DriverRow(driver: driver, raceLike: snapshot.isRaceOrSprint),
        ],
      ),
    );
  }
}

class _DriverRow extends StatelessWidget {
  const _DriverRow({required this.driver, required this.raceLike});

  final LiveDriverPosition driver;
  final bool raceLike;

  /// 상세 줄 공용 스타일(타이어 랩 수·PIT·섹터).
  static const TextStyle _detailStyle = TextStyle(
    color: AppColors.faint,
    fontSize: 9,
    fontWeight: FontWeight.w700,
  );

  @override
  Widget build(BuildContext context) {
    // 라이브 타이밍 보드 시안 참고: 항목을 라벨링해 처음 보는 사람도 읽게
    // 한다 — 타이어는 컴파운드 색 링 배지 + '7랩', 섹터는 S1/S2/S3 라벨.
    final sectors = <String>[
      if (driver.sector1 != null) 'S1 ${driver.sector1}',
      if (driver.sector2 != null) 'S2 ${driver.sector2}',
      if (driver.sector3 != null) 'S3 ${driver.sector3}',
    ].join(' · ');
    final hasTyreLine = driver.compound != null || driver.pitStops != null;
    final status = driver.retired
        ? 'OUT'
        : driver.inPit
        ? 'PIT'
        : driver.time(raceLike: raceLike);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(
            width: 3,
            height: 29,
            decoration: BoxDecoration(
              color: liveDriverAccent(driver.code),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 39,
            child: Text(
              driver.code,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.nameMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasTyreLine) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (driver.compound != null) ...[
                        _TyreBadge(compound: driver.compound!),
                        if (driver.tyreAge != null) ...[
                          const SizedBox(width: 4),
                          Text('${driver.tyreAge}랩', style: _detailStyle),
                        ],
                      ],
                      if (driver.pitStops != null) ...[
                        if (driver.compound != null) const SizedBox(width: 10),
                        Text('PIT ${driver.pitStops}', style: _detailStyle),
                      ],
                    ],
                  ),
                ],
                if (sectors.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    sectors,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _detailStyle,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(
              color: driver.inPit || driver.retired
                  ? AppColors.redSoft
                  : AppColors.slate300,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
      width: 15,
      height: 15,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _compoundColor(compound), width: 2),
      ),
      child: Text(
        _compoundShort(compound),
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 8,
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
          else
            for (final message in messages.take(12))
              _ControlMessage(message: message),
        ],
      ),
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
