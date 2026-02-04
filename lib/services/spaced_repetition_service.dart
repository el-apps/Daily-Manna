import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/database/database.dart'
    show AppDatabase, Result, ResultType;

/// Represents the spaced repetition state for a verse.
class VerseReviewState {
  final ScriptureRef ref;
  final DateTime lastReview;
  final int intervalDays;
  final int repetitions;

  VerseReviewState({
    required this.ref,
    required this.lastReview,
    required this.intervalDays,
    required this.repetitions,
  });

  DateTime get nextReviewDate => lastReview.add(Duration(days: intervalDays));

  bool get isDue => !DateTime.now().isBefore(nextReviewDate);
}

/// Service for calculating spaced repetition intervals.
///
/// Uses a simple doubling algorithm: 1, 2, 4, 8, 16, 32 days.
/// Scores below 90% reset the interval back to 1 day.
class SpacedRepetitionService {
  static const _intervals = [1, 2, 4, 8, 16, 32];
  static const _passingScore = 0.90;

  final AppDatabase _db;

  SpacedRepetitionService(this._db);

  /// Get all practiced verses sorted by next review date.
  Future<List<VerseReviewState>> getVersesByReviewDate() async {
    final allStates = await _getAllVerseStates();
    return _sortByReviewDate(allStates);
  }

  /// Watch all practiced verses sorted by next review date (reactive stream).
  Stream<List<VerseReviewState>> watchVersesByReviewDate() =>
      _db.watchAllResults().map((results) {
        final allStates = _computeAllVerseStates(results);
        return _sortByReviewDate(allStates);
      });

  /// Watch count of verses due for review (reactive stream).
  Stream<int> watchDueCount() => watchVersesByReviewDate().map((states) {
        final today = DateTime.now();
        final endOfToday =
            DateTime(today.year, today.month, today.day, 23, 59, 59);
        return states
            .where((s) => !s.nextReviewDate.isAfter(endOfToday))
            .length;
      });

  List<VerseReviewState> _sortByReviewDate(List<VerseReviewState> states) {
    states.sort((a, b) {
      // Primary sort: next review date
      final dateCompare = a.nextReviewDate.compareTo(b.nextReviewDate);
      if (dateCompare != 0) return dateCompare;

      // Secondary sort: book, chapter, verse
      final bookCompare = a.ref.bookId!.compareTo(b.ref.bookId!);
      if (bookCompare != 0) return bookCompare;

      final chapterCompare = a.ref.chapterNumber!.compareTo(
        b.ref.chapterNumber!,
      );
      if (chapterCompare != 0) return chapterCompare;

      return a.ref.verseNumber!.compareTo(b.ref.verseNumber!);
    });
    return states;
  }

  /// Get count of verses due for review (overdue + due today).
  Future<int> getDueCount() async {
    final allStates = await _getAllVerseStates();
    final today = DateTime.now();
    final endOfToday = DateTime(today.year, today.month, today.day, 23, 59, 59);
    return allStates.where((s) => !s.nextReviewDate.isAfter(endOfToday)).length;
  }

  /// Get recently practiced verses (by last review date).
  Future<List<VerseReviewState>> getRecentVerses({int limit = 20}) async {
    final allStates = await _getAllVerseStates();
    allStates.sort((a, b) => b.lastReview.compareTo(a.lastReview));
    return allStates.take(limit).toList();
  }

  /// Calculate SR state for all practiced verses.
  /// Expands passage ranges into individual verses.
  Future<List<VerseReviewState>> _getAllVerseStates() async {
    final allResults = await _db.getAllResults();
    return _computeAllVerseStates(allResults);
  }

  /// Compute SR states from a list of results (synchronous, for use with streams).
  List<VerseReviewState> _computeAllVerseStates(List<Result> allResults) {
    // Expand all results into individual verses and group by verse
    final verseResults = <String, List<Result>>{};

    for (final result in allResults) {
      final verses = _expandRange(result);
      for (final verse in verses) {
        final key =
            '${verse.bookId}:${verse.chapterNumber}:${verse.verseNumber}';
        verseResults.putIfAbsent(key, () => []).add(result);
      }
    }

    // Calculate SR state for each unique verse
    final states = <VerseReviewState>[];
    for (final entry in verseResults.entries) {
      // Skip verses that only have study entries (no practice results)
      final hasPractice = entry.value.any((r) => r.type != ResultType.study);
      if (!hasPractice) continue;

      final parts = entry.key.split(':');
      final ref = ScriptureRef(
        bookId: parts[0],
        chapterNumber: int.parse(parts[1]),
        verseNumber: int.parse(parts[2]),
      );

      // Sort by timestamp ascending to replay history
      final results = entry.value
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      states.add(_calculateState(ref, results));
    }

    return states;
  }

  /// Expand a result's passage range into individual verse references.
  List<ScriptureRef> _expandRange(Result result) {
    final endVerse = result.endVerse ?? result.startVerse;
    return [
      for (int v = result.startVerse; v <= endVerse; v++)
        ScriptureRef(
          bookId: result.bookId,
          chapterNumber: result.startChapter,
          verseNumber: v,
        ),
    ];
  }

  /// Replay result history to calculate current interval.
  /// Assumes at least one practice result exists (study-only filtered upstream).
  VerseReviewState _calculateState(ScriptureRef ref, List<Result> results) {
    // Filter out study entries - they don't affect SR intervals
    final practiceResults =
        results.where((r) => r.type != ResultType.study).toList();

    int reps = 0;

    for (final result in practiceResults) {
      if (result.score >= _passingScore) {
        // Passing score - advance reps (no cap during counting)
        reps++;
      } else {
        // Failing score - reset to beginning
        reps = 0;
      }
    }

    // Map reps to interval index (1-indexed reps to 0-indexed array)
    // reps=1 -> index 0 -> interval 1
    // reps=6 -> index 5 -> interval 32
    // reps=10 -> index 5 (capped) -> interval 32
    final intervalIndex = (reps - 1).clamp(0, _intervals.length - 1);

    return VerseReviewState(
      ref: ref,
      lastReview: practiceResults.last.timestamp,
      intervalDays: reps == 0 ? _intervals[0] : _intervals[intervalIndex],
      repetitions: reps,
    );
  }
}
