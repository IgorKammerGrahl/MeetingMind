import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetingmind/data/meeting_repository.dart';
import 'package:meetingmind/data/models/meeting.dart';
import 'package:meetingmind/data/models/processing_status.dart';
import 'package:meetingmind/features/history/history_screen.dart';
import 'package:meetingmind/providers/providers.dart';

class FakeRepo implements MeetingRepository {
  final List<MeetingSummary> summaries;
  FakeRepo(this.summaries);

  @override
  Future<List<MeetingSummary>> list() async => summaries;

  @override
  Future<Meeting> get(String id) async =>
      const Meeting(id: '1', status: ProcessingStatus.completed);

  @override
  Future<String> upload(String filePath, {String filename = 'r.m4a'}) async => 'id';
}

Widget _app(MeetingRepository repo) => ProviderScope(
      overrides: [meetingRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: HistoryScreen()),
    );

void main() {
  testWidgets('renders meeting rows with title and failed marker', (tester) async {
    final repo = FakeRepo([
      MeetingSummary(
        id: '1',
        status: ProcessingStatus.completed,
        title: 'Reunião de planejamento',
        createdAt: DateTime(2026, 7, 3, 16, 20),
      ),
      MeetingSummary(
        id: '2',
        status: ProcessingStatus.failed,
        title: '',
        createdAt: DateTime(2026, 7, 2, 9, 5),
      ),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Reunião de planejamento'), findsOneWidget);
    // Untitled failed row falls back to its date, with the status as meta.
    expect(find.text('02 Jul · 09:05'), findsOneWidget);
    expect(find.text("didn't come through"), findsOneWidget);
  });

  testWidgets('shows quiet empty state', (tester) async {
    await tester.pumpWidget(_app(FakeRepo([])));
    await tester.pumpAndSettle();
    expect(find.text('Nothing kept yet.'), findsOneWidget);
  });
}
