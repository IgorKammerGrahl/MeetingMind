import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/quiet_copy.dart';
import '../../core/theme.dart';
import '../../data/models/meeting.dart';
import '../../data/models/processing_status.dart';
import '../../providers/providers.dart';

/// History — every kept meeting, newest first. Quiet Brief language: no cards,
/// rows separated by 1px hairlines, mono metadata, no spinner.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late Future<List<MeetingSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(meetingRepositoryProvider).list();
  }

  void _reload() {
    setState(() => _future = ref.read(meetingRepositoryProvider).list());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 4),
                  Text('MeetingMind', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(QuietCopy.historyTitle,
                  style: theme.textTheme.displaySmall),
            ),
            Expanded(
              child: FutureBuilder<List<MeetingSummary>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return _CenteredNote(
                      text: QuietCopy.timeout,
                      action: OutlinedButton(
                        onPressed: _reload,
                        child: const Text(QuietCopy.tryAgainAction),
                      ),
                    );
                  }
                  if (!snap.hasData) return const _HistorySkeleton();
                  final items = snap.data!;
                  if (items.isEmpty) {
                    return const _CenteredNote(text: QuietCopy.historyEmpty);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    itemCount: items.length,
                    separatorBuilder: (_, i) =>
                        Divider(height: 1, thickness: 1, color: theme.dividerColor),
                    itemBuilder: (context, i) => _HistoryRow(
                      summary: items[i],
                      onOpen: () => _open(items[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(MeetingSummary s) async {
    switch (s.status) {
      case ProcessingStatus.completed:
        final meeting = await ref.read(meetingRepositoryProvider).get(s.id);
        if (mounted) context.go('/dashboard', extra: meeting);
      case ProcessingStatus.failed:
        break; // nothing to show
      default:
        context.go('/processing/${s.id}'); // resume polling
    }
  }
}

class _HistoryRow extends StatelessWidget {
  final MeetingSummary summary;
  final VoidCallback onOpen;
  const _HistoryRow({required this.summary, required this.onOpen});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _date {
    final d = summary.createdAt;
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} · $hh:$mm';
  }

  String get _statusWord {
    switch (summary.status) {
      case ProcessingStatus.completed:
        return '';
      case ProcessingStatus.failed:
        return QuietCopy.historyFailed;
      default:
        return QuietCopy.historyInProgress;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Untitled meetings lead with their date; the meta line then carries only
    // the status word so the date never appears twice.
    final untitled = summary.title.isEmpty;
    final title = untitled ? _date : summary.title;
    final meta = untitled
        ? _statusWord
        : (_statusWord.isEmpty ? _date : '$_date · $_statusWord');
    final failed = summary.status == ProcessingStatus.failed;

    return InkWell(
      onTap: failed ? null : onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Opacity(
          opacity: failed ? 0.55 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(meta, style: theme.extension<QuietTypeExtension>()?.meta),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CenteredNote extends StatelessWidget {
  final String text;
  final Widget? action;
  const _CenteredNote({required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text,
              style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    );
  }
}

/// Static hairline placeholders shaped like real rows (design language: no
/// spinner). No shimmer — VISUAL_DENSITY stays low, motion stays quiet.
class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: 4,
      separatorBuilder: (_, i) => Divider(height: 1, thickness: 1, color: color),
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 180, height: 16, color: color),
            const SizedBox(height: 8),
            Container(width: 96, height: 12, color: color),
          ],
        ),
      ),
    );
  }
}
