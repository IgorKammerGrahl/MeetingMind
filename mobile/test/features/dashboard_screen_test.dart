import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetingmind/data/models/meeting.dart';
import 'package:meetingmind/data/models/processing_status.dart';
import 'package:meetingmind/features/meeting/dashboard_screen.dart';

void main() {
  testWidgets('renders title, summary, and task with priority', (tester) async {
    const meeting = Meeting(
      id: '1',
      status: ProcessingStatus.completed,
      knowledge: MeetingKnowledge(
        title: 'Sprint Planning',
        summary: 'We planned the sprint.',
        meetingType: 'standup',
        tasks: [
          Task(responsible: 'John', task: 'Send the document', deadline: 'tomorrow', priority: 'high'),
        ],
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: DashboardScreen(meeting: meeting)));

    expect(find.text('Sprint Planning'), findsOneWidget);
    expect(find.text('We planned the sprint.'), findsOneWidget);
    expect(find.text('Send the document'), findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);
  });

  testWidgets('shows empty-tasks message', (tester) async {
    const meeting = Meeting(
      id: '2',
      status: ProcessingStatus.completed,
      knowledge: MeetingKnowledge(title: 'Sync', summary: 'x', meetingType: 'general', tasks: []),
    );
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen(meeting: meeting)));
    expect(find.text('Nothing was asked of anyone.'), findsOneWidget);
  });
}
