import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Caches the last backend base URL that answered a health check, so most
/// app launches skip network discovery entirely.
abstract final class BackendStore {
  static Future<File> _marker() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/backend_base_url');
  }

  static Future<String?> readLastBaseUrl() async {
    try {
      final file = await _marker();
      if (!await file.exists()) return null;
      final value = (await file.readAsString()).trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeLastBaseUrl(String baseUrl) async {
    try {
      await (await _marker()).writeAsString(baseUrl);
    } catch (_) {
      // Non-fatal: worst case discovery runs again next launch.
    }
  }
}
