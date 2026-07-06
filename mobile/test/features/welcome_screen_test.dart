import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meetingmind/core/quiet_copy.dart';
import 'package:meetingmind/features/welcome/welcome_screen.dart';
import 'package:meetingmind/providers/providers.dart';
import 'package:meetingmind/providers/recording_controller.dart';

class _FakePort implements RecorderPort {
  bool permissionRequested = false;

  @override
  Future<bool> hasPermission() async {
    permissionRequested = true;
    return true;
  }

  @override
  Future<void> start(String path) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<String?> stop() async => null;
  @override
  Stream<double> amplitude(Duration interval) => const Stream.empty();
}

void main() {
  testWidgets('shows the manifesto and requests the microphone on Begin', (tester) async {
    final port = _FakePort();
    final router = GoRouter(
      initialLocation: '/welcome',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordingControllerProvider.overrideWith(
            (ref) => RecordingController(port, () async => '/tmp/x.m4a'),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    expect(find.text(QuietCopy.welcomeHeadline), findsOneWidget);
    expect(find.text(QuietCopy.welcomeAction), findsOneWidget);

    await tester.tap(find.text(QuietCopy.welcomeAction));
    await tester.pumpAndSettle();

    expect(port.permissionRequested, true);
  });
}
