import 'package:daily_manna/practice_result.dart';
import 'package:daily_manna/recitation_result.dart';

class ResultsService {
  final List<MemorizationResult> _memorizationResults = [];
  final List<RecitationResult> _recitationResults = [];

  List<MemorizationResult> get memorizationResults =>
      List.unmodifiable(_memorizationResults);

  List<RecitationResult> get recitationResults =>
      List.unmodifiable(_recitationResults);

  void addMemorizationResult(MemorizationResult result) =>
      _memorizationResults.add(result);

  void addRecitationResult(RecitationResult result) =>
      _recitationResults.add(result);

  void clear() {
    _memorizationResults.clear();
    _recitationResults.clear();
  }
}
