class MorroApiConfig {
  /// Backend base URL.
  ///
  /// You can override at build time via:
  /// `--dart-define=MORRO_BACKEND_BASE_URL=...`
  static const String baseUrl = String.fromEnvironment(
    'MORRO_BACKEND_BASE_URL',
    defaultValue: 'https://donita-rudimentary-undisputedly.ngrok-free.dev',
  );

  /// Farm id used by the app.
  ///
  /// You can override at build time via:
  /// `--dart-define=MORRO_FARM_ID=...`
  static const String farmId = String.fromEnvironment('MORRO_FARM_ID', defaultValue: 'farm-1');
}
