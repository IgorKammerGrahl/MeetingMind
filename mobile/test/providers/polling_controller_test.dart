import 'package:flutter_test/flutter_test.dart';
import 'package:meetingmind/data/meeting_repository.dart';
import 'package:meetingmind/data/models/meeting.dart';
import 'package:meetingmind/data/models/processing_status.dart';
import 'package:meetingmind/providers/polling_controller.dart';

class ScriptedRepo implements MeetingRepository {
  final List<Meeting> script;
  int calls = 0;
  ScriptedRepo(this.script);

  @override
  Future<Meeting> get(String id) async {
    final idx = calls < script.length ? calls : script.length - 1;
    calls++;
    return script[idx];
  }

  @override
  Future<String> upload(String filePath, {String filename = 'r.m4a'}) async => 'id';
}

void main() {
  test('stops polling when completed', () async {
    final repo = ScriptedRepo(const [
      Meeting(id: '1', status: ProcessingStatus.transcribing),
      Meeting(id: '1', status: ProcessingStatus.analyzing),
      Meeting(
        id: '1',
        status: ProcessingStatus.completed,
        knowledge: MeetingKnowledge(title: 'T', summary: 'S', meetingType: 'standup', tasks: []),
      ),
    ]);
    final c = PollingController(repo, '1', interval: Duration.zero, maxAttempts: 10);
    await c.start();

    expect(c.state.meeting!.status, ProcessingStatus.completed);
    expect(repo.calls, 3);
  });

  test('times out after maxAttempts', () async {
    final repo = ScriptedRepo(const [
      Meeting(id: '1', status: ProcessingStatus.transcribing),
    ]);
    final c = PollingController(repo, '1', interval: Duration.zero, maxAttempts: 3);
    await c.start();

    expect(c.state.error, isNotNull);
    expect(repo.calls, 3);
  });
}
