import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../data/models/meeting.dart';
import 'signal_tag.dart';

/// Item row (task/risk): 2px colored priority tick, item title, meta line, right-aligned tag.
/// No pill, no fill (design language §6).
class TaskRow extends StatelessWidget {
  final Task task;
  const TaskRow({super.key, required this.task});

  Color _tickColor(SignalColors signals) {
    switch (task.priority) {
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
    final meta = [
      if (task.responsible.isNotEmpty) task.responsible,
      if (task.deadline.isNotEmpty) task.deadline,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 2, height: 40, color: _tickColor(signals)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.task, style: theme.textTheme.titleMedium),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(meta, style: theme.extension<QuietTypeExtension>()?.meta),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SignalTag(priority: task.priority),
        ],
      ),
    );
  }
}
