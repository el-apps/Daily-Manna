import 'package:daily_manna/models/scripture_range_ref.dart';

class RecitationResult {
  RecitationResult({required this.ref, required this.score});
  final ScriptureRangeRef ref;
  final double score;
}
