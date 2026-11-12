/// Build-time configuration.
///
/// Override with: flutter run --dart-define=API_URL=http://10.0.2.2:8000
/// (10.0.2.2 is your machine's localhost from the Android emulator.)
abstract final class Env {
  static const apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8000',
  );
}
