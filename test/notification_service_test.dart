import 'package:daily_manna/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationService.buildNotificationBody', () {
    test('returns message with both reviews and streak', () {
      final body = NotificationService.buildNotificationBody(3, 5);
      expect(
        body,
        'You have 3 verses to review. Keep your 5 day streak going!',
      );
    });

    test('returns streak only message when 0 reviews', () {
      final body = NotificationService.buildNotificationBody(0, 5);
      expect(body, 'Keep your 5 day streak going!');
    });

    test('returns reviews only message when 0 streak', () {
      final body = NotificationService.buildNotificationBody(3, 0);
      expect(body, 'You have 3 verses to review.');
    });

    test('returns default message when neither reviews nor streak', () {
      final body = NotificationService.buildNotificationBody(0, 0);
      expect(body, 'Start a daily habit in the Word!');
    });

    test('uses singular "verse" for 1 review', () {
      final body = NotificationService.buildNotificationBody(1, 0);
      expect(body, 'You have 1 verse to review.');
    });

    test('uses singular "day" for 1 day streak', () {
      final body = NotificationService.buildNotificationBody(0, 1);
      expect(body, 'Keep your 1 day streak going!');
    });

    test('uses singular forms for both 1 review and 1 day streak', () {
      final body = NotificationService.buildNotificationBody(1, 1);
      expect(
        body,
        'You have 1 verse to review. Keep your 1 day streak going!',
      );
    });
  });
}
