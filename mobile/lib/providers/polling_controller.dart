import 'package:flutter_riverpod/legacy.dart';

import '../data/meeting_repository.dart';
import '../data/models/meeting.dart';
import '../data/models/processing_status.dart';

class PollingState {
  final Meeting? meeting;
  final String? error;
  const PollingState({this.meeting, this.error});
}

class PollingController extends StateNotifier<PollingState> {
  final MeetingRepository _repo;
  final String meetingId;
  final Duration interval;
  final int maxAttempts;

  PollingController(
    this._repo,
    this.meetingId, {
    this.interval = const Duration(seconds: 3),
    this.maxAttempts = 60,
  }) : super(const PollingState());

  Future<void> start() async {
    for (var i = 0; i < maxAttempts; i++) {
      try {
        final m = await _repo.get(meetingId);
        state = PollingState(meeting: m);
        if (m.status == ProcessingStatus.completed ||
            m.status == ProcessingStatus.failed) {
          return;
        }
      } catch (_) {
        // transient network error; keep polling
      }
      await Future.delayed(interval);
    }
    state = PollingState(meeting: state.meeting, error: 'Processing timed out');
  }
}
