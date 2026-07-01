import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/quiet_copy.dart';
import '../../providers/providers.dart';
import '../../providers/recording_controller.dart';
import 'widgets/record_ring.dart';

/// Record — design language §8.1. No app-bar chrome; a faint wordmark top-left only.
class RecordingScreen extends ConsumerWidget {
  const RecordingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingControllerProvider);
    final controller = ref.read(recordingControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, left: 24),
              child: Text('MeetingMind', style: theme.textTheme.bodyMedium),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _headline(state.phase),
                      style: theme.textTheme.displaySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    RecordRing(live: state.phase == RecordingPhase.recording),
                    const SizedBox(height: 24),
                    ..._actions(context, ref, state.phase, controller),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _headline(RecordingPhase phase) {
    switch (phase) {
      case RecordingPhase.idle:
      case RecordingPhase.stopped:
        return QuietCopy.recordIdle;
      case RecordingPhase.recording:
        return QuietCopy.recording;
      case RecordingPhase.paused:
        return QuietCopy.paused;
    }
  }

  List<Widget> _actions(
    BuildContext context,
    WidgetRef ref,
    RecordingPhase phase,
    RecordingController controller,
  ) {
    switch (phase) {
      case RecordingPhase.idle:
      case RecordingPhase.stopped:
        return [
          OutlinedButton(
            onPressed: controller.startRecording,
            child: const Text(QuietCopy.recordAction),
          ),
        ];
      case RecordingPhase.recording:
        return [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(onPressed: controller.pause, child: const Text(QuietCopy.pauseAction)),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: () => _stopAndUpload(context, ref),
                child: const Text(QuietCopy.stopAction),
              ),
            ],
          ),
        ];
      case RecordingPhase.paused:
        return [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(onPressed: controller.resume, child: const Text(QuietCopy.resumeAction)),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: () => _stopAndUpload(context, ref),
                child: const Text(QuietCopy.stopAction),
              ),
            ],
          ),
        ];
    }
  }

  Future<void> _stopAndUpload(BuildContext context, WidgetRef ref) async {
    final path = await ref.read(recordingControllerProvider.notifier).stop();
    if (path == null) return;
    final id = await ref.read(meetingRepositoryProvider).upload(path);
    if (context.mounted) context.go('/processing/$id');
  }
}
