import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/services/score_display.dart';

class RecitationResult {
  RecitationResult({required this.ref, required this.score});
  final ScriptureRangeRef ref;
  final double score;

  String get scoreDisplay => ScoreDisplay.scoreToEmoji(score);
}
