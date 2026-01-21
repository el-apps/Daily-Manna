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
}
