import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// A large thin ring with a centered dot (design language §6). Idle = hollow.
/// Recording = `sig-live` dot, slow breathe. Respects Reduce Motion (§7).
class RecordRing extends StatefulWidget {
  final bool live;
  const RecordRing({super.key, required this.live});

  @override
  State<RecordRing> createState() => _RecordRingState();
}

class _RecordRingState extends State<RecordRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.live) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(RecordRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.live && !oldWidget.live) {
      _controller.repeat(reverse: true);
    } else if (!widget.live && oldWidget.live) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signals = theme.extension<SignalColors>() ?? SignalColors.light;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Widget? dot;
    if (widget.live) {
      final dotShape = Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(color: signals.sigLive, shape: BoxShape.circle),
      );
      dot = reduceMotion
          ? dotShape
          : AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Opacity(
                opacity: 0.4 + 0.6 * _controller.value,
                child: child,
              ),
              child: dotShape,
            );
    }

    return SizedBox(
      width: 120,
      height: 120,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.onSurface, width: 2),
        ),
        child: Center(child: dot),
      ),
    );
  }
}
