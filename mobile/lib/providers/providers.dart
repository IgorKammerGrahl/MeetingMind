import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../core/config.dart';
import '../data/meeting_api.dart';
import '../data/meeting_repository.dart';
import 'polling_controller.dart';
import 'recording_controller.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));
});

final meetingApiProvider =
    Provider<MeetingApi>((ref) => MeetingApi(ref.watch(dioProvider)));

final meetingRepositoryProvider = Provider<MeetingRepository>(
    (ref) => ApiMeetingRepository(ref.watch(meetingApiProvider)));

final pollingControllerProvider =
    StateNotifierProvider.family<PollingController, PollingState, String>(
  (ref, id) => PollingController(ref.watch(meetingRepositoryProvider), id),
);

final recordingControllerProvider =
    StateNotifierProvider<RecordingController, RecordingState>((ref) {
  return RecordingController(RecordAudioRecorder(), _tempAudioPath);
});

Future<String> _tempAudioPath() async {
  final dir = await getTemporaryDirectory();
  return '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
}

/// Real RecorderPort backed by the `record` plugin.
class RecordAudioRecorder implements RecorderPort {
  final AudioRecorder _rec = AudioRecorder();

  @override
  Future<bool> hasPermission() => _rec.hasPermission();
  @override
  Future<void> start(String path) => _rec.start(const RecordConfig(), path: path);
  @override
  Future<void> pause() => _rec.pause();
  @override
  Future<void> resume() => _rec.resume();
  @override
  Future<String?> stop() => _rec.stop();
}
