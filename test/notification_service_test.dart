import 'package:daily_manna/services/notification_service.dart';
import 'package:flutter/material.dart';
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

  group('NotificationService.calculateDelayUntilTime', () {
    test('schedules for today when time is in the future', () {
      // Current time: 8:00 AM, scheduled time: 10:00 AM
      final now = DateTime(2024, 6, 15, 8, 0);
      const time = TimeOfDay(hour: 10, minute: 0);

      final delay = NotificationService.calculateDelayUntilTime(time, now: now);

      // Should be 2 hours
      expect(delay.inMinutes, 120);
    });

    test('schedules for tomorrow when time has passed', () {
      // Current time: 10:00 AM, scheduled time: 8:00 AM
      final now = DateTime(2024, 6, 15, 10, 0);
      const time = TimeOfDay(hour: 8, minute: 0);

      final delay = NotificationService.calculateDelayUntilTime(time, now: now);

      // Should be 22 hours (until 8am tomorrow)
      expect(delay.inMinutes, 22 * 60);
    });

    test('schedules for tomorrow when time equals current time', () {
      // Current time: exactly 8:00 AM, scheduled time: 8:00 AM
      final now = DateTime(2024, 6, 15, 8, 0);
      const time = TimeOfDay(hour: 8, minute: 0);

      final delay = NotificationService.calculateDelayUntilTime(time, now: now);

      // Should be 24 hours (tomorrow)
      expect(delay.inMinutes, 24 * 60);
    });

    test('schedules for tomorrow when within buffer time', () {
      // Current time: 7:59:30 AM (30 seconds before 8am)
      // Scheduled time: 8:00 AM
      // Buffer is 60 seconds, so 8:00 AM is within buffer
      final now = DateTime(2024, 6, 15, 7, 59, 30);
      const time = TimeOfDay(hour: 8, minute: 0);

      final delay = NotificationService.calculateDelayUntilTime(time, now: now);

      // Should schedule for tomorrow (~24 hours from now)
      // 24 hours = 1440 minutes, minus 30 seconds we're before 8am = ~1439.5 minutes
      expect(delay.inHours, 24);
      expect(delay.inMinutes, closeTo(24 * 60, 1));
    });

    test('handles month boundary correctly', () {
      // Current time: Jan 31, 10:00 PM, scheduled time: 6:00 AM
      final now = DateTime(2024, 1, 31, 22, 0);
      const time = TimeOfDay(hour: 6, minute: 0);

      final delay = NotificationService.calculateDelayUntilTime(time, now: now);

      // Should be 8 hours (to Feb 1 at 6am)
      expect(delay.inMinutes, 8 * 60);
    });

    test('handles year boundary correctly', () {
      // Current time: Dec 31, 10:00 PM, scheduled time: 6:00 AM
      final now = DateTime(2024, 12, 31, 22, 0);
      const time = TimeOfDay(hour: 6, minute: 0);

      final delay = NotificationService.calculateDelayUntilTime(time, now: now);

      // Should be 8 hours (to Jan 1 at 6am)
      expect(delay.inMinutes, 8 * 60);
    });
  });
}

