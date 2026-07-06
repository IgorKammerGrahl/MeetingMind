import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// A large thin ring with a centered dot (design language §6). Idle = hollow.
/// Recording = `sig-live` dot, slow breathe, plus a soft halo and dot scale
/// driven by the mic [level] stream. Respects Reduce Motion (§7).
class RecordRing extends StatefulWidget {
  final bool live;

  /// Normalized 0..1 input level; null when not recording.
  final Stream<double>? level;

  const RecordRing({super.key, required this.live, this.level});

  @override
  State<RecordRing> createState() => _RecordRingState();
}

class _RecordRingState extends State<RecordRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  StreamSubscription<double>? _levelSub;
  double _level = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.live) _controller.repeat(reverse: true);
    _listenToLevel();
  }

  @override
  void didUpdateWidget(RecordRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.live && !oldWidget.live) {
      _controller.repeat(reverse: true);
    } else if (!widget.live && oldWidget.live) {
      _controller.stop();
    }
    if (widget.level != oldWidget.level) _listenToLevel();
  }

  void _listenToLevel() {
    _levelSub?.cancel();
    _levelSub = widget.level?.listen((v) {
      if (mounted) setState(() => _level = v);
    });
    if (widget.level == null && _level != 0) _level = 0;
  }

  @override
  void dispose() {
    _levelSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signals = theme.extension<SignalColors>() ?? SignalColors.light;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Widget? center;
    if (widget.live) {
      final dotShape = Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(color: signals.sigLive, shape: BoxShape.circle),
      );
      if (reduceMotion) {
        center = dotShape;
      } else {
        final haloSize = 20 + 80 * _level;
        center = Stack(
          alignment: Alignment.center,
          children: [
            // Voice halo: swells with the mic level, quiet-noir soft.
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              width: haloSize,
              height: haloSize,
              decoration: BoxDecoration(
                color: signals.sigLive.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Opacity(
                opacity: 0.4 + 0.6 * _controller.value,
                child: child,
              ),
              child: AnimatedScale(
                scale: 1 + 0.9 * _level,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: dotShape,
              ),
            ),
          ],
        );
      }
    }

    return SizedBox(
      width: 120,
      height: 120,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.onSurface, width: 2),
        ),
        child: Center(child: center),
      ),
    );
  }
}
