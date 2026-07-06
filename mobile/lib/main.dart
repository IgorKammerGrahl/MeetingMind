import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/backend_locator.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final baseUrl = await resolveApiBaseUrl();
  runApp(ProviderScope(
    overrides: [apiBaseUrlProvider.overrideWithValue(baseUrl)],
    child: const MeetingMindApp(),
  ));
}

class MeetingMindApp extends StatelessWidget {
  const MeetingMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MeetingMind',
      theme: buildQuietBriefTheme(),
      routerConfig: router,
    );
  }
}
