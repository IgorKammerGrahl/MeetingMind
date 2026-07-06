import 'package:flutter_riverpod/legacy.dart';

enum RecordingPhase { idle, recording, paused, stopped }

class RecordingState {
  final RecordingPhase phase;
  final String? path;
  final bool permissionDenied;
  const RecordingState({
    this.phase = RecordingPhase.idle,
    this.path,
    this.permissionDenied = false,
  });
}

/// Abstraction over the platform audio recorder, so the controller is testable.
abstract class RecorderPort {
  Future<bool> hasPermission();
  Future<void> start(String path);
  Future<void> pause();
  Future<void> resume();
  Future<String?> stop();

  /// Input level while recording, normalized 0..1.
  Stream<double> amplitude(Duration interval);
}

class RecordingController extends StateNotifier<RecordingState> {
  final RecorderPort _recorder;
  final Future<String> Function() _pathBuilder;

  RecordingController(this._recorder, this._pathBuilder)
      : super(const RecordingState());

  Future<void> startRecording() async {
    if (!await _recorder.hasPermission()) {
      state = RecordingState(phase: state.phase, permissionDenied: true);
      return;
    }
    final path = await _pathBuilder();
    await _recorder.start(path);
    state = RecordingState(phase: RecordingPhase.recording, path: path);
  }

  /// Requests microphone access ahead of time (welcome screen), without
  /// starting a recording.
  Future<bool> requestPermission() => _recorder.hasPermission();

  Future<void> pause() async {
    await _recorder.pause();
    state = RecordingState(phase: RecordingPhase.paused, path: state.path);
  }

  Future<void> resume() async {
    await _recorder.resume();
    state = RecordingState(phase: RecordingPhase.recording, path: state.path);
  }

  Future<String?> stop() async {
    final path = await _recorder.stop();
    state = RecordingState(phase: RecordingPhase.stopped, path: path ?? state.path);
    return state.path;
  }

  Stream<double> amplitude(
          [Duration interval = const Duration(milliseconds: 100)]) =>
      _recorder.amplitude(interval);
}
