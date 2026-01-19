import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/database/database.dart';

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

  bool get isDue => DateTime.now().isAfter(nextReviewDate) ||
      DateTime.now().day == nextReviewDate.day &&
          DateTime.now().month == nextReviewDate.month &&
          DateTime.now().year == nextReviewDate.year;
}

/// Service for calculating spaced repetition intervals using SM-2 algorithm.
class SpacedRepetitionService {
  final AppDatabase _db;

  SpacedRepetitionService(this._db);

  /// Convert score (0.5-1.0) to SM-2 quality (0-5).
  static int scoreToQuality(double score) => ((score * 10) - 5).round().clamp(0, 5);

  /// Get all verses that are due for review.
  Future<List<VerseReviewState>> getDueVerses() async {
    final allStates = await _getAllVerseStates();
    return allStates.where((state) => state.isDue).toList()
      ..sort((a, b) => a.nextReviewDate.compareTo(b.nextReviewDate));
  }

  /// Get recently practiced verses (by last review date).
  Future<List<VerseReviewState>> getRecentVerses({int limit = 20}) async {
    final allStates = await _getAllVerseStates();
    allStates.sort((a, b) => b.lastReview.compareTo(a.lastReview));
    return allStates.take(limit).toList();
  }

  /// Calculate SR state for all practiced verses.
  Future<List<VerseReviewState>> _getAllVerseStates() async {
    final uniqueVerses = await _db.getUniqueVersesPracticed();
    final states = <VerseReviewState>[];

    for (final verse in uniqueVerses) {
      final results = await _db.getResultsForVerse(
        verse.bookId,
        verse.chapter,
        verse.verse,
      );

      if (results.isEmpty) continue;

      // Sort by timestamp ascending to replay history
      results.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final state = _calculateState(
        ScriptureRef(
          bookId: verse.bookId,
          chapterNumber: verse.chapter,
          verseNumber: verse.verse,
        ),
        results,
      );

      states.add(state);
    }

    return states;
  }

  /// Replay result history to calculate current SM-2 state.
  VerseReviewState _calculateState(ScriptureRef ref, List<Result> results) {
    double ef = 2.5;
    int interval = 1;
    int reps = 0;
    DateTime lastReview = results.last.timestamp;

    for (final result in results) {
      final quality = scoreToQuality(result.score);
      lastReview = result.timestamp;

      if (quality >= 3) {
        // Correct response
        if (reps == 0) {
          interval = 1;
        } else if (reps == 1) {
          interval = 6;
        } else {
          interval = (interval * ef).round();
        }
        reps++;
      } else {
        // Incorrect response - reset
        reps = 0;
        interval = 1;
      }

      // Update ease factor
      ef = ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
      if (ef < 1.3) ef = 1.3;
    }

    return VerseReviewState(
      ref: ref,
      lastReview: lastReview,
      intervalDays: interval,
      easeFactor: ef,
      repetitions: reps,
    );
  }
}
