/// URL pública do Render; pode ser substituída via --dart-define=API_BASE_URL=...
/// Não inclua tokens ou senhas no aplicativo.
class ApiConfig {
  static const String backendOnlineUrl = 'https://s-ig-a.onrender.com/api';
  static const bool demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);
}
