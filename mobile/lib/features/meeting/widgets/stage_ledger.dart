import 'package:flutter/material.dart';

import '../../../core/quiet_copy.dart';
import '../../../core/theme.dart';
import '../../../data/models/processing_status.dart';

enum _StageMark { done, active, pending }

/// Vertical stage list replacing the spinner (design language §6/§8.2).
/// done ✓ (ink), active dot (accent), pending hairline dot (ink-tertiary).
class StageLedger extends StatelessWidget {
  final ProcessingStatus status;
  const StageLedger({super.key, required this.status});

  static const _labels = [
    QuietCopy.stageTranscribed,
    QuietCopy.stageUnderstanding,
    QuietCopy.stageOrdering,
  ];

  int get _activeIndex {
    switch (status) {
      case ProcessingStatus.uploaded:
      case ProcessingStatus.transcribing:
        return 0;
      case ProcessingStatus.analyzing:
        return 1;
      case ProcessingStatus.completed:
      case ProcessingStatus.failed:
        return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = theme.extension<QuietTypeExtension>()?.meta;
    final allDone = status == ProcessingStatus.completed;
    final active = _activeIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_labels.length, (i) {
        final mark = allDone
            ? _StageMark.done
            : i < active
                ? _StageMark.done
                : i == active
                    ? _StageMark.active
                    : _StageMark.pending;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(child: Text(_labels[i], style: meta)),
              _Marker(mark: mark),
            ],
          ),
        );
      }),
    );
  }
}

class _Marker extends StatelessWidget {
  final _StageMark mark;
  const _Marker({required this.mark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (mark) {
      case _StageMark.done:
        return Text('✓', style: TextStyle(color: theme.colorScheme.onSurface));
      case _StageMark.active:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
        );
      case _StageMark.pending:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
        );
    }
  }
}
