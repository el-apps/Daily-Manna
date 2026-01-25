import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/database/database.dart'
    show AppDatabase, Result, ResultType;

/// Represents the spaced repetition state for a verse.
class VerseReviewState {
  final ScriptureRef ref;
  final DateTime lastReview;
  final int intervalDays;
  final double easeFactor;
  final int repetitions;

  VerseReviewState({
    required this.ref,
    required this.lastReview,
    required this.intervalDays,
    required this.easeFactor,
    required this.repetitions,
  });

  DateTime get nextReviewDate => lastReview.add(Duration(days: intervalDays));

  bool get isDue => !DateTime.now().isBefore(nextReviewDate);
}

/// Service for calculating spaced repetition intervals using SM-2 algorithm.
class SpacedRepetitionService {
  // SM-2 algorithm constants
  static const _initialEaseFactor = 2.5;
  static const _minimumEaseFactor = 1.3;
  static const _firstInterval = 1;
  static const _secondInterval = 6;
  static const _passingQuality = 3;

  final AppDatabase _db;

  SpacedRepetitionService(this._db);

  /// Convert score (0.5-1.0) to SM-2 quality (0-5).
  static int scoreToQuality(double score) =>
      ((score * 10) - 5).round().clamp(0, 5);

  /// Get all practiced verses sorted by next review date.
  Future<List<VerseReviewState>> getVersesByReviewDate() async {
    final allStates = await _getAllVerseStates();
    allStates.sort((a, b) {
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
    return allStates;
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

  /// Replay result history to calculate current SM-2 state.
  /// Assumes at least one practice result exists (study-only filtered upstream).
  VerseReviewState _calculateState(ScriptureRef ref, List<Result> results) {
    // Filter out study entries - they don't affect SR intervals
    final practiceResults =
        results.where((r) => r.type != ResultType.study).toList();

    double ef = _initialEaseFactor;
    int interval = _firstInterval;
    int reps = 0;

    for (final result in practiceResults) {
      final quality = scoreToQuality(result.score);

      if (quality >= _passingQuality) {
        // Correct response
        if (reps == 0) {
          interval = _firstInterval;
        } else if (reps == 1) {
          interval = _secondInterval;
        } else {
          interval = (interval * ef).round();
        }
        reps++;
      } else {
        // Incorrect response - reset
        reps = 0;
        interval = _firstInterval;
      }

      // Update ease factor using SM-2 formula
      final qualityDeficit = 5 - quality;
      final penaltyFactor = 0.08 + qualityDeficit * 0.02;
      final easeAdjustment = 0.1 - qualityDeficit * penaltyFactor;
      ef = (ef + easeAdjustment).clamp(_minimumEaseFactor, double.infinity);
    }

    return VerseReviewState(
      ref: ref,
      lastReview: practiceResults.last.timestamp,
      intervalDays: interval,
      easeFactor: ef,
      repetitions: reps,
    );
  }
}
