import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _whisperKeyKey = 'whisper_api_key';
  static const String _openRouterKeyKey = 'openrouter_api_key';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String? getWhisperApiKey() {
    return _prefs.getString(_whisperKeyKey);
  }

  Future<void> setWhisperApiKey(String key) async {
    await _prefs.setString(_whisperKeyKey, key);
  }

  String? getOpenRouterApiKey() {
    return _prefs.getString(_openRouterKeyKey);
  }

  Future<void> setOpenRouterApiKey(String key) async {
    await _prefs.setString(_openRouterKeyKey, key);
  }

  Future<void> clearWhisperApiKey() async {
    await _prefs.remove(_whisperKeyKey);
  }

  Future<void> clearOpenRouterApiKey() async {
    await _prefs.remove(_openRouterKeyKey);
  }

  bool hasRequiredKeys() {
    return getWhisperApiKey() != null && getOpenRouterApiKey() != null;
  }
}
