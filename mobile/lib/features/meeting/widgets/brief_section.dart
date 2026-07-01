import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// The one reusable primitive every knowledge type renders through (design language §5):
/// a label with an optional right-aligned mono count, then rows, separated from what came
/// before by whitespace + a hairline. Sections are never boxed.
class BriefSection extends StatelessWidget {
  final String label;
  final int? count;
  final List<Widget> children;

  const BriefSection({
    super.key,
    required this.label,
    this.count,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countStyle = theme.extension<QuietTypeExtension>()?.meta;

    return Padding(
      padding: const EdgeInsets.only(top: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
              if (count != null) Text('$count', style: countStyle),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
