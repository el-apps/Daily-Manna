import 'package:daily_manna/utils/date_utils.dart';
import 'package:daily_manna/services/database/database.dart'
    show AppDatabase, Result;

/// Represents the current streak state.
class StreakState {
  final int streakDays;
  final bool activityToday;

  const StreakState({required this.streakDays, required this.activityToday});
}

/// Computes the current streak from activity timestamps.
StreakState calculateStreakState(
  Iterable<DateTime> timestamps, {
  DateTime? now,
}) {
  final daysWithActivity = normalizeActivityDays(timestamps);
  if (daysWithActivity.isEmpty) {
    return const StreakState(streakDays: 0, activityToday: false);
  }

  final todayDate = (now ?? DateTime.now()).dateOnly;
  final activityToday = daysWithActivity.contains(todayDate);

  int streak = 0;
  DateTime checkDate = activityToday
      ? todayDate
      : todayDate.subtract(const Duration(days: 1));

  while (daysWithActivity.contains(checkDate)) {
    streak++;
    checkDate = checkDate.subtract(const Duration(days: 1));
  }

  return StreakState(streakDays: streak, activityToday: activityToday);
}

/// Service for calculating daily activity streaks.
class StreakService {
  final AppDatabase _db;

  StreakService(this._db);

  /// Watch the current streak state (reactive stream).
  Stream<StreakState> watchStreak() =>
      _db.watchAllResults().map(_computeStreak);

  /// Get the current streak state (one-time).
  Future<StreakState> getStreak() async {
    final results = await _db.getAllResults();
    return _computeStreak(results);
  }

  /// Compute streak from results.
  StreakState _computeStreak(List<Result> results) =>
      calculateStreakState(results.map((result) => result.timestamp));
}
