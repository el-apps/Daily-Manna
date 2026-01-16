import 'package:daily_manna/scripture_range_ref.dart';

class RecitationResult {
  RecitationResult({required this.ref, required this.score});
  final ScriptureRangeRef ref;
  final double score;

  int get percentage => (score * 100).toInt();
}
