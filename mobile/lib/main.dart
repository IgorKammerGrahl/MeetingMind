import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';

void main() => runApp(const ProviderScope(child: MeetingMindApp()));

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
