import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/quiet_copy.dart';
import '../../core/welcome_store.dart';
import '../../providers/providers.dart';
import '../../providers/recording_controller.dart';
import 'widgets/record_ring.dart';

/// Record — design language §8.1. No app-bar chrome; a faint wordmark top-left only.
class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  bool _uploading = false;
  bool _uploadFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!await WelcomeStore.hasSeenWelcome() && mounted) {
        context.go('/welcome');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: TextButton(
                  onPressed: () => context.push('/history'),
                  child: const Text(QuietCopy.historyAction),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _headline(state),
                      style: theme.textTheme.displaySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    RecordRing(
                      live: state.phase == RecordingPhase.recording,
                      level: state.phase == RecordingPhase.recording
                          ? controller.amplitude()
                          : null,
                    ),
                    const SizedBox(height: 24),
                    ..._actions(state, controller),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _headline(RecordingState state) {
    if (_uploading) return QuietCopy.uploading;
    if (_uploadFailed) return QuietCopy.uploadFailed;
    if (state.permissionDenied) return QuietCopy.micDenied;
    switch (state.phase) {
      case RecordingPhase.idle:
      case RecordingPhase.stopped:
        return QuietCopy.recordIdle;
      case RecordingPhase.recording:
        return QuietCopy.recording;
      case RecordingPhase.paused:
        return QuietCopy.paused;
    }
  }

  List<Widget> _actions(RecordingState state, RecordingController controller) {
    switch (state.phase) {
      case RecordingPhase.idle:
      case RecordingPhase.stopped:
        if (_uploadFailed && state.path != null) {
          return [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: _uploading ? null : _startOver,
                  child: const Text(QuietCopy.recordAction),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: _uploading ? null : () => _upload(state.path!),
                  child: const Text(QuietCopy.retryUploadAction),
                ),
              ],
            ),
          ];
        }
        if (state.permissionDenied) {
          return [
            OutlinedButton(
              onPressed: controller.startRecording,
              child: const Text(QuietCopy.tryAgainAction),
            ),
          ];
        }
        return [
          OutlinedButton(
            onPressed: _uploading ? null : controller.startRecording,
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
                onPressed: _uploading ? null : _stopAndUpload,
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
                onPressed: _uploading ? null : _stopAndUpload,
                child: const Text(QuietCopy.stopAction),
              ),
            ],
          ),
        ];
    }
  }

  void _startOver() {
    setState(() => _uploadFailed = false);
    ref.read(recordingControllerProvider.notifier).startRecording();
  }

  Future<void> _stopAndUpload() async {
    final path = await ref.read(recordingControllerProvider.notifier).stop();
    if (path == null) return;
    await _upload(path);
  }

  Future<void> _upload(String path) async {
    setState(() {
      _uploading = true;
      _uploadFailed = false;
    });
    try {
      final id = await ref.read(meetingRepositoryProvider).upload(path);
      if (mounted) context.go('/processing/$id');
    } catch (_) {
      // The local file survives; the user can retry from here.
      if (mounted) setState(() => _uploadFailed = true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}
