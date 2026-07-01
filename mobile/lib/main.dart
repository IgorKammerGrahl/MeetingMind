import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';

void main() => runApp(const ProviderScope(child: MeetingMindApp()));

class MeetingMindApp extends StatelessWidget {
  const MeetingMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeetingMind',
      theme: buildQuietBriefTheme(),
      home: Scaffold(appBar: AppBar(title: const Text('MeetingMind'))),
    );
  }
}
