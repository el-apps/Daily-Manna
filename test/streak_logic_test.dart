import 'package:daily_manna/services/streak_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculateStreakState', () {
    test('returns 0 when there are no activity days', () {
      final state = calculateStreakState([]);

      expect(state.streakDays, 0);
      expect(state.activityToday, false);
    });

    test('uses local calendar days for UTC timestamps', () {
      final latest = DateTime.utc(2024, 1, 16, 3);
      final state = calculateStreakState([
        latest,
        latest.subtract(const Duration(days: 1)),
      ], now: latest.toLocal());

      expect(state.streakDays, 2);
      expect(state.activityToday, true);
    });

    test('stops at the first missing local day', () {
      final state = calculateStreakState([
        DateTime(2024, 1, 15, 9),
        DateTime(2024, 1, 13, 9),
      ], now: DateTime(2024, 1, 15, 12));

      expect(state.streakDays, 1);
      expect(state.activityToday, true);
    });
  });
}
