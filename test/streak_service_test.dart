import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/services/streak_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late StreakService streakService;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    streakService = StreakService(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> addResultOnDate(DateTime date) async {
    await database.insertResult(
      ResultsCompanion.insert(
        timestamp: date,
        type: ResultType.study,
        bookId: 'Gen',
        startChapter: 1,
        startVerse: 1,
        score: 1.0,
      ),
    );
  }

  group('StreakService', () {
    test('returns 0 streak with no results', () async {
      final states = <StreakState>[];
      final subscription = streakService.watchStreak().listen(states.add);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.last.streakDays, 0);
      expect(states.last.activityToday, false);

      await subscription.cancel();
    });

    test('returns 1 day streak with activity today', () async {
      final today = DateTime.now();
      await addResultOnDate(today);

      final states = <StreakState>[];
      final subscription = streakService.watchStreak().listen(states.add);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.last.streakDays, 1);
      expect(states.last.activityToday, true);

      await subscription.cancel();
    });

    test('returns streak at risk when no activity today', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await addResultOnDate(yesterday);

      final states = <StreakState>[];
      final subscription = streakService.watchStreak().listen(states.add);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.last.streakDays, 1);
      expect(states.last.activityToday, false);

      await subscription.cancel();
    });

    test('counts consecutive days correctly', () async {
      final now = DateTime.now();
      // Add activity for today and 2 previous days
      await addResultOnDate(now);
      await addResultOnDate(now.subtract(const Duration(days: 1)));
      await addResultOnDate(now.subtract(const Duration(days: 2)));

      final states = <StreakState>[];
      final subscription = streakService.watchStreak().listen(states.add);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.last.streakDays, 3);
      expect(states.last.activityToday, true);

      await subscription.cancel();
    });

    test('breaks streak on gap day', () async {
      final now = DateTime.now();
      // Add activity for today and 2 days ago (skip yesterday)
      await addResultOnDate(now);
      await addResultOnDate(now.subtract(const Duration(days: 2)));

      final states = <StreakState>[];
      final subscription = streakService.watchStreak().listen(states.add);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.last.streakDays, 1); // Only today counts
      expect(states.last.activityToday, true);

      await subscription.cancel();
    });

    test('streak at risk counts from yesterday', () async {
      final now = DateTime.now();
      // Activity yesterday and day before, but not today
      await addResultOnDate(now.subtract(const Duration(days: 1)));
      await addResultOnDate(now.subtract(const Duration(days: 2)));

      final states = <StreakState>[];
      final subscription = streakService.watchStreak().listen(states.add);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.last.streakDays, 2);
      expect(states.last.activityToday, false);

      await subscription.cancel();
    });

    test('multiple results on same day count as one day', () async {
      final now = DateTime.now();
      await addResultOnDate(now);
      await addResultOnDate(now.subtract(const Duration(hours: 2)));
      await addResultOnDate(now.subtract(const Duration(hours: 5)));

      final states = <StreakState>[];
      final subscription = streakService.watchStreak().listen(states.add);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.last.streakDays, 1);
      expect(states.last.activityToday, true);

      await subscription.cancel();
    });

    test('updates reactively when result is added', () async {
      final states = <StreakState>[];
      final subscription = streakService.watchStreak().listen(states.add);

      await Future.delayed(const Duration(milliseconds: 100));
      expect(states.last.streakDays, 0);

      // Add activity
      await addResultOnDate(DateTime.now());

      await Future.delayed(const Duration(milliseconds: 100));
      expect(states.last.streakDays, 1);
      expect(states.last.activityToday, true);

      await subscription.cancel();
    });
  });
}
