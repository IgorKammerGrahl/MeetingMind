import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/meeting.dart';
import 'widgets/brief_section.dart';
import 'widgets/task_row.dart';

/// The Brief — design language §8.3. Reads like a prepared meeting brief:
/// meta → title → summary as standfirst → Section(s) → quiet signature footer.
/// MVP scope renders Summary + Tasks only (locked decision, 2026-07-01).
class DashboardScreen extends StatelessWidget {
  final Meeting meeting;
  final VoidCallback? onNewRecording;

  const DashboardScreen({super.key, required this.meeting, this.onNewRecording});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final k = meeting.knowledge;

    return Scaffold(
      body: SafeArea(
        child: k == null
            ? const Center(child: Text('No results available.'))
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                children: [
                  if (k.meetingType.isNotEmpty)
                    Text(k.meetingType, style: theme.extension<QuietTypeExtension>()?.meta),
                  const SizedBox(height: 8),
                  Text(
                    k.title.isNotEmpty ? k.title : 'Meeting',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    k.summary.isNotEmpty ? k.summary : 'The conversation left no clear thread.',
                    style: theme.textTheme.titleLarge,
                  ),
                  BriefSection(
                    label: 'Tasks',
                    count: k.tasks.isEmpty ? null : k.tasks.length,
                    children: k.tasks.isEmpty
                        ? [Text('Nothing was asked of anyone.', style: theme.textTheme.bodyMedium)]
                        : k.tasks.map((t) => TaskRow(task: t)).toList(),
                  ),
                  const SizedBox(height: 44),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Every meeting deserves\na second memory.',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: onNewRecording,
                          child: const Text('New recording'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
