import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/drivers.dart';
import '../data/standings.dart' as static_standings;
import '../models/race.dart';
import '../models/race_poll.dart';
import '../models/standing.dart';
import '../services/polls_repository.dart';
import '../services/standings_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';
import 'my_picks_card.dart';

/// GP 상세의 '팬 투표' 카드 — 우승·폴 예측과 레이스 평점.
///
/// Box Box 의 레이스 평점, Sofascore 승부 예측처럼 계정 없이 가볍게 참여하는
/// 장치(2026-11 개선 목록). 서버가 GP 를 모르거나(404) 실패하면 카드를 통째로
/// 숨긴다. 예측 분포는 결과가 아니라서 스포일러가 아니다.
class RacePollsCard extends StatefulWidget {
  const RacePollsCard({
    super.key,
    required this.race,
    this.repository,
    this.standingsRepository,
  });

  final Race race;

  /// 테스트 주입 지점.
  final PollsRepository? repository;

  /// 예측 선택 시트의 드라이버 순위·포인트 출처(테스트 주입 지점).
  final StandingsRepository? standingsRepository;

  @override
  State<RacePollsCard> createState() => _RacePollsCardState();
}

class _RacePollsCardState extends State<RacePollsCard> {
  late final PollsRepository _repository =
      widget.repository ?? PollsRepository();

  RacePoll? _poll;
  final Map<PollKind, String?> _mine = {};
  bool _voting = false;

  /// 선택 시트에 보여 줄 드라이버 순위. 번들 정적 순위로 시작해 서버 순위가
  /// 오면 교체한다 — 정적 값만 쓰면 시즌이 진행될수록 순위·포인트가 어긋난다
  /// (MY PICKS 카드와 같은 방식, 6시간 공유 캐시라 추가 요청은 거의 없다).
  List<DriverStanding> _drivers = static_standings.driverStandings;

  @override
  void initState() {
    super.initState();
    _load();
    _loadStandings();
  }

  Future<void> _loadStandings() async {
    final repo = widget.standingsRepository ?? const HttpStandingsRepository();
    try {
      final snapshot = await repo.fetchLatest();
      if (!mounted || snapshot == null) return;
      setState(() => _drivers = snapshot.driverStandings);
    } catch (_) {
      // 정적 순위 유지.
    }
  }

  Future<void> _load() async {
    final poll = await _repository.fetch(widget.race.id);
    final mine = {
      for (final kind in PollKind.values)
        kind: await _repository.myVote(widget.race.id, kind),
    };
    if (!mounted) return;
    setState(() {
      _poll = poll;
      _mine.addAll(mine);
    });
  }

  Future<void> _vote(PollKind kind, Object value) async {
    if (_voting) return;
    setState(() => _voting = true);
    final result = await _repository.vote(
      raceId: widget.race.id,
      kind: kind,
      value: value,
    );
    if (!mounted) return;
    setState(() {
      _voting = false;
      if (result.poll != null) {
        _poll = result.poll;
        _mine[kind] = '$value';
      }
    });
    if (result.poll != null) {
      HapticFeedback.selectionClick();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(switch (result.error) {
          VoteError.closed => '투표가 마감됐어요.',
          VoteError.rateLimited => '잠시 후 다시 시도해 주세요.',
          _ => '투표를 보내지 못했어요.',
        }),
      ),
    );
  }

  Future<void> _pickDriver(PollKind kind, String title) async {
    final result = await showModalBottomSheet<MyPickResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MyDriverPickerSheet(
        current: _mine[kind],
        drivers: _drivers,
        title: title,
        subtitle: '누가 가져갈까요?',
        allowClear: false,
        includeUnranked: false,
      ),
    );
    final code = result?.value;
    if (code != null && mounted) await _vote(kind, code);
  }

  @override
  Widget build(BuildContext context) {
    final poll = _poll;
    if (poll == null) return const SizedBox.shrink();
    final showPole = poll.pole.open || poll.pole.total > 0;
    final showWinner = poll.winner.open || poll.winner.total > 0;
    final showRating = poll.rating.open || poll.rating.total > 0;
    if (!showPole && !showWinner && !showRating) return const SizedBox.shrink();

    final sections = <Widget>[
      if (showPole)
        _PickSection(
          title: '폴 예측',
          tally: poll.pole,
          mine: _mine[PollKind.pole],
          busy: _voting,
          onPick: () => _pickDriver(PollKind.pole, '폴 예측'),
        ),
      if (showWinner)
        _PickSection(
          title: '우승 예측',
          tally: poll.winner,
          mine: _mine[PollKind.winner],
          busy: _voting,
          onPick: () => _pickDriver(PollKind.winner, '우승 예측'),
        ),
      if (showRating)
        _RatingSection(
          tally: poll.rating,
          mine: int.tryParse(_mine[PollKind.rating] ?? ''),
          busy: _voting,
          onRate: (stars) => _vote(PollKind.rating, stars),
        ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('팬 투표', style: AppType.headline.copyWith(color: AppColors.white)),
          for (final section in sections) ...[
            const SizedBox(height: 16),
            section,
          ],
        ],
      ),
    );
  }
}

class _PickSection extends StatelessWidget {
  const _PickSection({
    required this.title,
    required this.tally,
    required this.mine,
    required this.busy,
    required this.onPick,
  });

  final String title;
  final PickTally tally;
  final String? mine;
  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final top = tally.top(3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppType.subhead.copyWith(color: AppColors.white),
              ),
            ),
            Text(
              tally.open
                  ? '${tally.total}명 참여'
                  : '마감 · ${tally.total}명 참여',
              style: AppType.caption.copyWith(
                color: AppColors.textMuted,
                fontFeatures: AppType.tabular,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final (code, share) in top)
          _ShareBar(code: code, share: share, isMine: code == mine),
        if (top.isEmpty)
          Text(
            '첫 예측을 남겨 보세요.',
            style: AppType.caption.copyWith(color: AppColors.textMuted),
          ),
        if (tally.open)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: ValueKey('poll-pick-$title'),
              onPressed: busy ? null : onPick,
              child: Text(
                mine == null
                    ? '예측하기'
                    : '내 예측 ${driverNameKo(mine!, mine!)} · 바꾸기',
                style: AppType.subhead,
              ),
            ),
          ),
      ],
    );
  }
}

class _ShareBar extends StatelessWidget {
  const _ShareBar({
    required this.code,
    required this.share,
    required this.isMine,
  });

  final String code;
  final double share;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final accent = liveDriverAccent(code);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              driverNameKo(code, code),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.caption.copyWith(
                color: isMine ? AppColors.white : AppColors.textMuted,
                fontWeight: isMine ? FontWeight.w700 : null,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 6,
                color: accent,
                backgroundColor: AppColors.tileSurface,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${(share * 100).round()}%',
              textAlign: TextAlign.right,
              style: AppType.caption.copyWith(
                color: AppColors.white,
                fontFeatures: AppType.tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingSection extends StatelessWidget {
  const _RatingSection({
    required this.tally,
    required this.mine,
    required this.busy,
    required this.onRate,
  });

  final RatingTally tally;
  final int? mine;
  final bool busy;
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    final average = tally.average;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '레이스 평점',
                style: AppType.subhead.copyWith(color: AppColors.white),
              ),
            ),
            if (average != null)
              Text(
                '평균 ${average.toStringAsFixed(1)} · ${tally.total}명',
                style: AppType.caption.copyWith(
                  color: AppColors.textMuted,
                  fontFeatures: AppType.tabular,
                ),
              ),
          ],
        ),
        if (tally.open) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  key: ValueKey('poll-star-$star'),
                  tooltip: '$star점',
                  onPressed: busy ? null : () => onRate(star),
                  icon: Icon(
                    (mine ?? 0) >= star
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 32,
                    color: (mine ?? 0) >= star
                        ? AppColors.white
                        : AppColors.textMuted,
                  ),
                ),
            ],
          ),
          if (mine == null)
            Text(
              '이번 레이스, 몇 점 주시겠어요?',
              textAlign: TextAlign.center,
              style: AppType.caption.copyWith(color: AppColors.textMuted),
            ),
        ],
      ],
    );
  }
}
