import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../data/drivers.dart';
import '../models/live_session.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';

/// 지금 무전을 재생 중인 차량 번호. 트랙맵이 이 값을 보고 해당 차량을
/// 강조한다(카드끼리 상태를 넘기려고 둔 전역 신호 — 라이브 센터 한 화면 안에서만 쓴다).
final ValueNotifier<String?> liveTalkingRacingNumber = ValueNotifier<String?>(
  null,
);

/// 라이브 센터 팀 라디오(2026-10).
///
/// 목록은 live.json `teamRadio`(최신순 20건)이고, 재생 버튼을 누를 때만
/// F1 정적 서버의 mp3 를 직접 스트리밍한다(한 건 100~700KB, 우리 서버 비용 0).
/// 플레이어는 첫 재생 때 만든다 — 목록만 보는 사용자는 오디오 세션을 잡지 않는다.
class LiveTeamRadioCard extends StatefulWidget {
  const LiveTeamRadioCard({
    super.key,
    required this.radios,
    required this.drivers,
    this.clock,
    this.emptyMessage = '아직 들어온 무전이 없어요',
  });

  /// 무전이 없을 때 안내(카드는 평소에도 뜬다 — 사용자 요청 2026-10).
  final String emptyMessage;

  final List<LiveTeamRadio> radios;
  final List<LiveDriverPosition> drivers;
  final DateTime Function()? clock;

  @override
  State<LiveTeamRadioCard> createState() => _LiveTeamRadioCardState();
}

class _LiveTeamRadioCardState extends State<LiveTeamRadioCard> {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSub;
  String? _playingUrl;
  String? _loadingUrl;

  @override
  void dispose() {
    _stateSub?.cancel();
    _player?.dispose();
    if (_playingUrl != null) liveTalkingRacingNumber.value = null;
    super.dispose();
  }

  Future<void> _toggle(LiveTeamRadio radio) async {
    if (_playingUrl == radio.url) {
      await _stop();
      return;
    }
    final player = _player ??= AudioPlayer();
    _stateSub ??= player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) _stop();
    });
    setState(() {
      _loadingUrl = radio.url;
      _playingUrl = null;
    });
    try {
      await player.setUrl(radio.url);
      if (!mounted) return;
      setState(() {
        _loadingUrl = null;
        _playingUrl = radio.url;
      });
      liveTalkingRacingNumber.value = radio.racingNumber;
      await player.play();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingUrl = null;
        _playingUrl = null;
      });
      liveTalkingRacingNumber.value = null;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('무전을 재생하지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  Future<void> _stop() async {
    await _player?.stop();
    if (!mounted) return;
    setState(() {
      _playingUrl = null;
      _loadingUrl = null;
    });
    liveTalkingRacingNumber.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final byNumber = {
      for (final d in widget.drivers)
        if (d.racingNumber != null) d.racingNumber!: d,
    };
    final now = (widget.clock ?? DateTime.now)();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '팀 라디오',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              // 빈 상태에선 '0건' 대신 아래 안내 문구만 둔다.
              if (widget.radios.isNotEmpty)
                Text(
                  '${widget.radios.length}건',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.radios.isEmpty)
            Text(
              widget.emptyMessage,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            )
          else
            ConstrainedBox(
              // 레이스 컨트롤 카드처럼 고정 높이 안에서 스크롤 — 20건이 화면을 밀지 않게.
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: widget.radios.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final radio = widget.radios[index];
                  return _RadioRow(
                    radio: radio,
                    driver: byNumber[radio.racingNumber],
                    now: now,
                    playing: _playingUrl == radio.url,
                    loading: _loadingUrl == radio.url,
                    onTap: () => _toggle(radio),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.radio,
    required this.driver,
    required this.now,
    required this.playing,
    required this.loading,
    required this.onTap,
  });

  final LiveTeamRadio radio;
  final LiveDriverPosition? driver;
  final DateTime now;
  final bool playing;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final code = driver?.code ?? '#${radio.racingNumber}';
    final name = driver == null
        ? ''
        : driverNameKo(driver!.code, driver!.displayName);
    final accent = driver == null
        ? AppColors.muted
        : liveDriverAccent(driver!.code);
    final kst = radio.utc.toUtc().add(const Duration(hours: 9));
    final clock =
        '${kst.hour.toString().padLeft(2, '0')}:${kst.minute.toString().padLeft(2, '0')}';
    final age = now.difference(radio.utc);
    final fresh = age.inSeconds < 60;
    final ago = age.inSeconds < 60
        ? '방금'
        : age.inMinutes < 60
        ? '${age.inMinutes}분 전'
        : '${age.inHours}시간 전';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.resultRowSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          code,
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '$clock · $ago',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                        if (fresh) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.red.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'NEW',
                              style: TextStyle(
                                color: AppColors.redSoft,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Semantics(
                button: true,
                label: '$code 무전 ${playing ? '정지' : '재생'}',
                child: Material(
                  color: playing ? AppColors.textSoft : AppColors.red,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onTap,
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: loading
                          ? Padding(
                              padding: const EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onAccent,
                              ),
                            )
                          : Icon(
                              playing
                                  ? Icons.stop_rounded
                                  : Icons.play_arrow_rounded,
                              size: 20,
                              color: playing
                                  ? AppColors.background
                                  : AppColors.onAccent,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
