import 'package:go_router/go_router.dart';

import '../data/models/meeting.dart';
import '../features/history/history_screen.dart';
import '../features/meeting/dashboard_screen.dart';
import '../features/meeting/processing_screen.dart';
import '../features/recording/recording_screen.dart';
import '../features/welcome/welcome_screen.dart';

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const RecordingScreen()),
    GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
    GoRoute(path: '/history', builder: (context, state) => const HistoryScreen()),
    GoRoute(
      path: '/processing/:id',
      builder: (context, state) =>
          ProcessingScreen(meetingId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => DashboardScreen(
        meeting: state.extra as Meeting,
        onNewRecording: () => context.go('/'),
      ),
    ),
  ],
);
