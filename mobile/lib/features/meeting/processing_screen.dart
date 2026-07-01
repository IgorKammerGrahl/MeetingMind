import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/quiet_copy.dart';
import '../../data/models/processing_status.dart';
import '../../providers/providers.dart';
import 'widgets/stage_ledger.dart';

/// Processing — design language §8.2. No CircularProgressIndicator, no percentage;
/// the StageLedger reflects the real lifecycle instead.
class ProcessingScreen extends ConsumerStatefulWidget {
  final String meetingId;
  const ProcessingScreen({super.key, required this.meetingId});

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pollingControllerProvider(widget.meetingId).notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(pollingControllerProvider(widget.meetingId));
    final meeting = state.meeting;

    if (meeting != null && meeting.status == ProcessingStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/dashboard', extra: meeting);
      });
    }

    final timedOut = state.error != null;
    final failed = meeting?.status == ProcessingStatus.failed;
    final headline = timedOut
        ? QuietCopy.timeout
        : failed
            ? QuietCopy.pipelineFailed
            : (meeting?.status ?? ProcessingStatus.uploaded).message;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(headline, style: theme.textTheme.displaySmall, textAlign: TextAlign.center),
                if (!timedOut && !failed) ...[
                  const SizedBox(height: 32),
                  StageLedger(status: meeting?.status ?? ProcessingStatus.uploaded),
                ],
                if (timedOut || failed) ...[
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => context.go('/'),
                    child: Text(timedOut ? QuietCopy.tryAgainAction : QuietCopy.startOverAction),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
