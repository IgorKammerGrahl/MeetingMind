import 'package:dio/dio.dart';

import 'backend_discovery.dart';
import 'backend_store.dart';
import 'config.dart';

/// Resolves the backend base URL without a hardcoded IP: reuse the last
/// address that worked, else broadcast-discover it on the LAN, else fall
/// back to the configured default. Every candidate is verified with a real
/// `/health` call before being trusted, so a stale cache never sticks.
Future<String> resolveApiBaseUrl() async {
  if (apiBaseUrlIsExplicit) return apiBaseUrl;

  final probe = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 1),
    receiveTimeout: const Duration(seconds: 1),
  ));

  Future<bool> healthy(String base) async {
    try {
      final res = await probe.get('$base/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  final cached = await BackendStore.readLastBaseUrl();
  if (cached != null && await healthy(cached)) return cached;

  final discovered = await BackendDiscovery.find();
  if (discovered != null && await healthy(discovered)) {
    await BackendStore.writeLastBaseUrl(discovered);
    return discovered;
  }

  return apiBaseUrl;
}
