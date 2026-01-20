import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/score_display.dart';

class MemorizationResult {
  MemorizationResult({
    required this.ref,
    required this.attempts,
    required this.score,
  });
  final ScriptureRef ref;
  final int attempts;
  final double score;

  String get scoreString =>
      ScoreDisplay.displayWithRetry(score, attempts: attempts);
}
