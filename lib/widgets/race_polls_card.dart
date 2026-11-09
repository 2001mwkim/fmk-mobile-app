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
///
/// 폴·우승을 나란한 타일로 비교하고 CTA 하나로 남은 예측을 이어서 받는다.
/// 고른 뒤 바꾸는 건 타일을 탭해서 한다(CTA 는 아직 안 고른 것만 묻는다).
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

  /// 표가 서버에 반영됐으면 true.
  Future<bool> _vote(PollKind kind, Object value) async {
    if (_voting) return false;
    setState(() => _voting = true);
    final result = await _repository.vote(
      raceId: widget.race.id,
      kind: kind,
      value: value,
    );
    if (!mounted) return false;
    setState(() {
      _voting = false;
      if (result.poll != null) {
        _poll = result.poll;
        _mine[kind] = '$value';
      }
    });
    if (result.poll != null) {
      HapticFeedback.selectionClick();
      return true;
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
    return false;
  }

  /// 선택기를 띄워 표를 낸다. 시트를 닫았거나 실패하면 false.
  Future<bool> _pickDriver(PollKind kind) async {
    final title = _pickTitles[kind]!;
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
    if (code == null || !mounted) return false;
    return _vote(kind, code);
  }

  /// CTA — 아직 안 고른 예측을 차례로 묻는다. 시트를 닫으면 거기서 멈춘다.
  Future<void> _voteRemaining(List<PollKind> kinds) async {
    for (final kind in kinds) {
      if (!await _pickDriver(kind) || !mounted) return;
    }
  }

  Widget _pickTile(PollKind kind, IconData icon, PickTally tally) {
    return _PickTile(
      title: _pickTitles[kind]!,
      icon: icon,
      tally: tally,
      mine: _mine[kind],
      busy: _voting,
      onPick: () => _pickDriver(kind),
    );
  }

  @override
  Widget build(BuildContext context) {
    final poll = _poll;
    if (poll == null) return const SizedBox.shrink();
    final showPole = poll.pole.open || poll.pole.total > 0;
    final showWinner = poll.winner.open || poll.winner.total > 0;
    final showRating = poll.rating.open || poll.rating.total > 0;
    if (!showPole && !showWinner && !showRating) return const SizedBox.shrink();

    final pickTiles = <Widget>[
      if (showPole)
        _pickTile(PollKind.pole, Icons.sports_score_rounded, poll.pole),
      if (showWinner)
        _pickTile(PollKind.winner, Icons.emoji_events_rounded, poll.winner),
    ];
    final pending = [
      if (poll.pole.open && _mine[PollKind.pole] == null) PollKind.pole,
      if (poll.winner.open && _mine[PollKind.winner] == null) PollKind.winner,
    ];
    final allVoted = pending.isEmpty && (poll.pole.open || poll.winner.open);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '팬 투표',
                  style: AppType.headline.copyWith(color: AppColors.white),
                ),
              ),
              if (allVoted) ...[
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '참여 완료',
                  style: AppType.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ],
          ),
          if (pickTiles.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            // 표가 없는 쪽이 있어도 두 타일의 높이를 맞춘다.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < pickTiles.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.xs),
                    Expanded(child: pickTiles[i]),
                  ],
                ],
              ),
            ),
          ],
          if (pending.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const ValueKey('poll-vote-cta'),
              onPressed: _voting ? null : () => _voteRemaining(pending),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: AppColors.onAccent,
                minimumSize: const Size.fromHeight(48),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.mediumBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('내 예측 투표하기', style: AppType.headline),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ),
          ],
          if (showRating) ...[
            if (pickTiles.isNotEmpty) const SizedBox(height: AppSpacing.xs),
            if (pickTiles.isEmpty) const SizedBox(height: AppSpacing.sm),
            _RatingSection(
              tally: poll.rating,
              mine: int.tryParse(_mine[PollKind.rating] ?? ''),
              busy: _voting,
              onRate: (stars) => _vote(PollKind.rating, stars),
            ),
          ],
        ],
      ),
    );
  }
}

const Map<PollKind, String> _pickTitles = {
  PollKind.pole: '폴 예측',
  PollKind.winner: '우승 예측',
};

/// 한글 이름의 성만 — 반폭 타일에 '오스카 피아스트리' 전체는 들어가지 않는다.
String _surnameKo(String code) => driverNameKo(code, code).split(' ').last;

/// 카드 안쪽의 무채색 타일. 테두리 없이 명도 차이로만 구분한다.
class _PollTile extends StatelessWidget {
  const _PollTile({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.tileSurface,
      borderRadius: AppRadius.mediumBorder,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: child,
        ),
      ),
    );
  }
}

class _TileTitle extends StatelessWidget {
  const _TileTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.subhead.copyWith(color: AppColors.white),
          ),
        ),
      ],
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.title,
    required this.icon,
    required this.tally,
    required this.mine,
    required this.busy,
    required this.onPick,
  });

  final String title;
  final IconData icon;
  final PickTally tally;
  final String? mine;
  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final top = tally.top(3);
    final mine = this.mine;
    return _PollTile(
      key: ValueKey('poll-pick-$title'),
      onTap: tally.open && !busy ? onPick : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TileTitle(icon: icon, title: title),
          const SizedBox(height: 2),
          Text(
            tally.open
                ? '${tally.total}명 참여'
                : '마감 · ${tally.total}명 참여',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption.copyWith(
              color: AppColors.textMuted,
              fontFeatures: AppType.tabular,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final (code, share) in top)
            _ShareBar(code: code, share: share, isMine: code == mine),
          if (top.isEmpty)
            Text(
              '첫 예측을 남겨 보세요.',
              style: AppType.caption.copyWith(color: AppColors.textMuted),
            ),
          if (mine != null) ...[
            const Spacer(),
            const SizedBox(height: AppSpacing.xxs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '내 예측 ${_surnameKo(mine)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(color: AppColors.white),
                  ),
                ),
                // 타일을 탭해 바꿀 수 있다는 표시 — 마감되면 없앤다.
                if (tally.open)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
          ],
        ],
      ),
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
    // 이름·막대·퍼센트를 한 줄에 두면 반폭 타일(폰에서 안쪽 약 120)에 12pt
    // 글자를 넣고 막대가 20 남짓만 남는다 — 이름/퍼센트와 막대를 두 줄로 나눈다.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _surnameKo(code),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption.copyWith(
                    color: isMine ? AppColors.white : AppColors.textMuted,
                    fontWeight: isMine ? FontWeight.w700 : null,
                  ),
                ),
              ),
              Text(
                '${(share * 100).round()}%',
                style: AppType.caption.copyWith(
                  color: AppColors.white,
                  fontFeatures: AppType.tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 6,
              color: accent,
              // 타일 위라서 트랙을 타일과 다른 명도로 둔다.
              backgroundColor: AppColors.hairline,
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
    return _PollTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _TileTitle(
                  icon: Icons.star_rounded,
                  title: '레이스 평점',
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
            const SizedBox(height: AppSpacing.xxs),
            // 별 5개(48×5)는 타일 패딩까지 더하면 320 폭 폰에서 넘친다.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
            ),
            if (mine == null)
              Text(
                '이번 레이스, 몇 점 주시겠어요?',
                textAlign: TextAlign.center,
                style: AppType.caption.copyWith(color: AppColors.textMuted),
              ),
          ],
        ],
      ),
    );
  }
}
