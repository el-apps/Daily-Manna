import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _openRouterKeyKey = 'openrouter_api_key';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _notificationTimeKey = 'notification_time';
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

  // Notification settings
  bool getNotificationsEnabled() =>
      _prefs.getBool(_notificationsEnabledKey) ?? true; // Default: enabled

  Future<void> setNotificationsEnabled(bool value) async =>
      await _prefs.setBool(_notificationsEnabledKey, value);

  TimeOfDay getNotificationTime() {
    final minutes = _prefs.getInt(_notificationTimeKey) ?? (6 * 60); // Default: 6:00 AM
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  Future<void> setNotificationTime(TimeOfDay time) async =>
      await _prefs.setInt(_notificationTimeKey, time.hour * 60 + time.minute);
}
