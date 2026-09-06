import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _notificationTimeKey = 'notification_time';
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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
