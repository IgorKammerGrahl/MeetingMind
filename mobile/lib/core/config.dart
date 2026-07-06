/// Fallback base URL of the MeetingMind backend, used only when both the
/// cached address and LAN discovery (`backend_locator.dart`) fail.
/// Android emulator reaches host localhost via 10.0.2.2.
const String _defaultBaseUrl = 'http://10.0.2.2:8080';

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: _defaultBaseUrl,
);

/// True when --dart-define=API_BASE_URL was passed explicitly, meaning the
/// developer wants a fixed address and discovery should be skipped.
const bool apiBaseUrlIsExplicit = apiBaseUrl != _defaultBaseUrl;
