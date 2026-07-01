import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetingmind/main.dart';
import 'package:meetingmind/providers/providers.dart';
import 'package:meetingmind/providers/recording_controller.dart';

class _FakePort implements RecorderPort {
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> start(String path) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<String?> stop() async => null;
}

void main() {
  testWidgets('boots to the recording screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordingControllerProvider.overrideWith(
            (ref) => RecordingController(_FakePort(), () async => '/tmp/x.m4a'),
          ),
        ],
        child: const MeetingMindApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MeetingMind'), findsOneWidget);
    expect(find.text('Record'), findsOneWidget);
  });
}
