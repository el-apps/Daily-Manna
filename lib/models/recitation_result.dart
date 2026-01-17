import 'package:daily_manna/models/scripture_range_ref.dart';

/// Convert score (0.0-1.0) to star count (0-5)
int scoreToStars(double score) => (score * 5).round().clamp(0, 5);

class RecitationResult {
  RecitationResult({required this.ref, required this.score});
  final ScriptureRangeRef ref;
  final double score;

  int get starRating => (score / 0.2).round().clamp(0, 5);

  String get starDisplay => _buildStarDisplay(starRating);

  static String _buildStarDisplay(int rating) {
    const fullStar = '⭐';
    const emptyStar = '☆';

    final fullCount = rating.clamp(0, 5);
    final emptyCount = 5 - fullCount;

    return fullStar * fullCount + emptyStar * emptyCount;
  }
}
