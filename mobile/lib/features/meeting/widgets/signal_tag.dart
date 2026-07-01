import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Mono uppercase priority/severity word + a small leading dot in functional color.
/// The entire "chip" vocabulary (design language §6) — never color alone.
class SignalTag extends StatelessWidget {
  final String priority;
  const SignalTag({super.key, required this.priority});

  Color _colorFor(SignalColors signals) {
    switch (priority) {
      case 'high':
        return signals.sigHigh;
      case 'low':
        return signals.sigLow;
      default:
        return signals.sigMed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signals = theme.extension<SignalColors>() ?? SignalColors.light;
    final color = _colorFor(signals);
    final tagStyle = theme.extension<QuietTypeExtension>()?.tag;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Text(priority.toUpperCase(), style: tagStyle?.copyWith(color: color)),
      ],
    );
  }
}
