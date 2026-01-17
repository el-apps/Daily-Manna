import 'package:daily_manna/models/result_item.dart';
import 'package:daily_manna/models/result_section.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/ui/memorization/practice_result.dart';
import 'package:daily_manna/models/recitation_result.dart';

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

  List<ResultSection> getSections(BibleService bibleService) => [
    if (_memorizationResults.isNotEmpty)
      ResultSection(
        title: 'Memorization',
        items: _memorizationResults
            .map(
              (result) => ResultItem(
                score: result.scoreString,
                reference: bibleService.getRefName(result.ref),
              ),
            )
            .toList(),
      ),
    if (_recitationResults.isNotEmpty)
      ResultSection(
        title: 'Recitation',
        items: _recitationResults
            .map(
              (result) => ResultItem(
                score: result.starDisplay,
                reference: bibleService.getRangeRefName(result.ref),
              ),
            )
            .toList(),
      ),
  ];
}
