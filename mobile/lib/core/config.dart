/// Base URL of the MeetingMind backend.
/// Android emulator reaches host localhost via 10.0.2.2.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);
