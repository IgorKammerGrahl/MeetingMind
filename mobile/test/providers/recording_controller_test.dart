import 'package:flutter_test/flutter_test.dart';
import 'package:meetingmind/providers/recording_controller.dart';

class FakePort implements RecorderPort {
  bool started = false, paused = false, resumed = false, stopped = false;

  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> start(String path) async => started = true;
  @override
  Future<void> pause() async => paused = true;
  @override
  Future<void> resume() async => resumed = true;
  @override
  Future<String?> stop() async {
    stopped = true;
    return '/tmp/rec.m4a';
  }
}

void main() {
  test('runs record → pause → resume → stop', () async {
    final port = FakePort();
    final c = RecordingController(port, () async => '/tmp/rec.m4a');

    await c.startRecording();
    expect(c.state.phase, RecordingPhase.recording);
    expect(port.started, true);

    await c.pause();
    expect(c.state.phase, RecordingPhase.paused);

    await c.resume();
    expect(c.state.phase, RecordingPhase.recording);

    final path = await c.stop();
    expect(c.state.phase, RecordingPhase.stopped);
    expect(path, '/tmp/rec.m4a');
  });

  test('does nothing without permission', () async {
    final c = RecordingController(_DeniedPort(), () async => '/tmp/rec.m4a');
    await c.startRecording();
    expect(c.state.phase, RecordingPhase.idle);
  });
}

class _DeniedPort implements RecorderPort {
  @override
  Future<bool> hasPermission() async => false;
  @override
  Future<void> start(String path) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<String?> stop() async => null;
}
