import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _openRouterKeyKey = 'openrouter_api_key';
  // Default API key injected at build time via --dart-define
  static const String _defaultApiKey = String.fromEnvironment(
    'DEFAULT_OPENROUTER_API_KEY',
    defaultValue: '',
  );

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String? getOpenRouterApiKey() {
    final stored = _prefs.getString(_openRouterKeyKey);
    // Return stored key if set, otherwise use default from build-time constant
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return _defaultApiKey.isNotEmpty ? _defaultApiKey : null;
  }

  Future<void> setOpenRouterApiKey(String key) async {
    await _prefs.setString(_openRouterKeyKey, key);
  }

  Future<void> clearOpenRouterApiKey() async {
    await _prefs.remove(_openRouterKeyKey);
  }

  bool hasRequiredKeys() {
    final openRouter = getOpenRouterApiKey();
    return openRouter != null && openRouter.isNotEmpty;
  }
}
