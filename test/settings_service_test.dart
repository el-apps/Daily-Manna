import 'package:daily_manna/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('notifications default to enabled at 6:00 AM', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();
    await settings.init();

    expect(settings.getNotificationsEnabled(), isTrue);
    expect(settings.getNotificationTime(), const TimeOfDay(hour: 6, minute: 0));
  });
}
