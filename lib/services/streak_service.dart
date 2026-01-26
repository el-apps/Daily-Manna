import 'package:daily_manna/services/database/database.dart'
    show AppDatabase, Result;

/// Represents the current streak state.
class StreakState {
  final int streakDays;
  final bool activityToday;

  const StreakState({required this.streakDays, required this.activityToday});
}

/// Service for calculating daily activity streaks.
class StreakService {
  final AppDatabase _db;

  StreakService(this._db);

  /// Watch the current streak state (reactive stream).
  Stream<StreakState> watchStreak() =>
      _db.watchAllResults().map(_computeStreak);

  /// Compute streak from results.
  StreakState _computeStreak(List<Result> results) {
    if (results.isEmpty) {
      return const StreakState(streakDays: 0, activityToday: false);
    }

    // Get unique days with activity (local time)
    final daysWithActivity = <DateTime>{};
    for (final result in results) {
      final date = DateTime(
        result.timestamp.year,
        result.timestamp.month,
        result.timestamp.day,
      );
      daysWithActivity.add(date);
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final activityToday = daysWithActivity.contains(todayDate);

    // Count consecutive days backwards
    int streak = 0;
    DateTime checkDate =
        activityToday ? todayDate : todayDate.subtract(const Duration(days: 1));

    while (daysWithActivity.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return StreakState(streakDays: streak, activityToday: activityToday);
  }
}
