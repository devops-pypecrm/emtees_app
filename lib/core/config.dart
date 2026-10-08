/// App-wide runtime configuration.
///
/// Values are supplied at build/run time via `--dart-define`, e.g.
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000/api/mobile`
///
/// Sensible defaults are provided for the Android emulator (10.0.2.2 maps to
/// the host machine's localhost).
class AppConfig {
  AppConfig._();

  /// Base URL for the REST API (mounted at /api/mobile on the backend).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/mobile',
  );

  /// Base URL for the raw backend origin (used for the Socket.IO connection).
  static const String socketBaseUrl = String.fromEnvironment(
    'SOCKET_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// Jitsi Meet server used for video calls.
  static const String jitsiServerUrl = String.fromEnvironment(
    'JITSI_SERVER_URL',
    defaultValue: 'https://meet.gecouncil.com',
  );
}
