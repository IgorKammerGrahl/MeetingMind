import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/quiet_copy.dart';
import '../../core/welcome_store.dart';
import '../../providers/providers.dart';

/// Welcome — shown once, ever. Same quiet-noir voice as Record, no chrome,
/// no logo mark, no exclamation. Begin requests the microphone up front so
/// Record never opens with a cold permission prompt.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _starting = false;

  Future<void> _begin() async {
    setState(() => _starting = true);
    await ref.read(recordingControllerProvider.notifier).requestPermission();
    await WelcomeStore.markSeen();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  QuietCopy.welcomeHeadline,
                  style: theme.textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                OutlinedButton(
                  onPressed: _starting ? null : _begin,
                  child: const Text(QuietCopy.welcomeAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
