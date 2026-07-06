import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Whether the user has passed the one-time welcome screen. Backed by a marker
/// file (no account, no backend — the device is the identity). Fails open: any
/// platform error is treated as "already seen" so a broken plugin never blocks
/// the user from recording.
abstract final class WelcomeStore {
  static Future<File> _marker() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/welcome_seen');
  }

  static Future<bool> hasSeenWelcome() async {
    try {
      return await (await _marker()).exists();
    } catch (_) {
      return true;
    }
  }

  static Future<void> markSeen() async {
    try {
      await (await _marker()).create(recursive: true);
    } catch (_) {
      // Non-fatal: worst case the welcome screen reappears once.
    }
  }
}
