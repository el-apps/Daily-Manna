import 'package:daily_manna/models/scripture_ref.dart';

class MemorizationResult {
  MemorizationResult({
    required this.ref,
    required this.attempts,
    required this.score,
  });
  final ScriptureRef ref;
  final int attempts;
  final double score;

  String get scoreString => switch ((attempts, score)) {
    (1, >= 0.9) => '🎉',
    (1, >= 0.5) => '✅',
    (_, >= 0.5) => '♻️',
    _ => '⛔',
  };
}
