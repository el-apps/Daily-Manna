import 'package:daily_manna/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('clearing the API key removes the custom override', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();
    await settings.init();

    await settings.setOpenRouterApiKey('custom-key');
    expect(settings.hasOpenRouterApiKeyOverride(), isTrue);
    expect(settings.getOpenRouterApiKey(), 'custom-key');

    await settings.clearOpenRouterApiKey();
    expect(settings.hasOpenRouterApiKeyOverride(), isFalse);
    expect(settings.getOpenRouterApiKey(), isNull);
  });
}
