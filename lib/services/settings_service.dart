import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _openRouterKeyKey = 'openrouter_api_key';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String? getOpenRouterApiKey() => _prefs.getString(_openRouterKeyKey);

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
