import 'package:flutter/material.dart';

import '../models/live_session.dart';
import '../services/live_session_controller.dart';

/// 전역 [liveSessionController] 를 구독해 최신 라이브 스냅샷으로 [builder] 를 다시 그린다.
///
/// 정적 화면 구조를 바꾸지 않고 라이브 위젯만 감싸는 용도. mount 시 폴링 리스너로
/// 등록되고, dispose 시 해제되어 마지막 화면이 사라지면 타이머가 정리된다.
class LiveSessionBuilder extends StatefulWidget {
  const LiveSessionBuilder({
    super.key,
    required this.builder,
    this.latestSession = false,
    this.controller,
  });

  /// true면 일반 라이브 노출 기한 대신 라이브 센터용 최근 세션을 구독한다.
  final bool latestSession;
  final LiveSessionController? controller;

  final Widget Function(
    BuildContext context,
    LiveSessionSnapshot? snapshot,
    bool isStale,
  )
  builder;

  @override
  State<LiveSessionBuilder> createState() => _LiveSessionBuilderState();
}

class _LiveSessionBuilderState extends State<LiveSessionBuilder> {
  LiveSessionController get _controller =>
      widget.controller ?? liveSessionController;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(covariant LiveSessionBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldController = oldWidget.controller ?? liveSessionController;
    if (oldController == _controller) return;
    oldController.removeListener(_onChange);
    _controller.addListener(_onChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return widget.builder(
      context,
      widget.latestSession
          ? controller.latestSessionSnapshot
          : controller.snapshot,
      widget.latestSession
          ? controller.latestSessionIsStale
          : controller.isStale,
    );
  }
}
