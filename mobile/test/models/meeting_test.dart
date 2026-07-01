import 'package:flutter_test/flutter_test.dart';
import 'package:meetingmind/data/models/meeting.dart';
import 'package:meetingmind/data/models/processing_status.dart';

void main() {
  test('parses a completed meeting', () {
    final json = {
      'id': 'abc',
      'status': 'completed',
      'error': '',
      'knowledge': {
        'title': 'Standup',
        'summary': 'Daily sync',
        'meeting_type': 'standup',
        'tasks': [
          {'responsible': 'John', 'task': 'send doc', 'deadline': 'tomorrow', 'priority': 'medium'}
        ],
      },
    };
    final m = Meeting.fromJson(json);
    expect(m.status, ProcessingStatus.completed);
    expect(m.knowledge!.title, 'Standup');
    expect(m.knowledge!.tasks.single.responsible, 'John');
    expect(m.error, isNull);
  });

  test('null knowledge while processing', () {
    final m = Meeting.fromJson({'id': 'x', 'status': 'transcribing', 'knowledge': null, 'error': null});
    expect(m.status, ProcessingStatus.transcribing);
    expect(m.knowledge, isNull);
  });

  test('fromString falls back to uploaded', () {
    expect(ProcessingStatus.fromString('analyzing'), ProcessingStatus.analyzing);
    expect(ProcessingStatus.fromString('bogus'), ProcessingStatus.uploaded);
  });

  test('status message is human readable', () {
    expect(ProcessingStatus.transcribing.message, contains('Catching'));
  });
}
