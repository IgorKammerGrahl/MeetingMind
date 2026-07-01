import 'meeting_api.dart';
import 'models/meeting.dart';

/// Abstraction the controllers depend on, so tests can supply fakes.
abstract class MeetingRepository {
  Future<String> upload(String filePath, {String filename});
  Future<Meeting> get(String id);
}

class ApiMeetingRepository implements MeetingRepository {
  final MeetingApi _api;
  ApiMeetingRepository(this._api);

  @override
  Future<String> upload(String filePath, {String filename = 'recording.m4a'}) =>
      _api.uploadMeeting(filePath, filename: filename);

  @override
  Future<Meeting> get(String id) => _api.getMeeting(id);
}
