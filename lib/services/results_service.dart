import 'package:daily_manna/models/recitation_result.dart';
import 'package:daily_manna/models/result_item.dart';
import 'package:daily_manna/models/result_section.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/ui/memorization/practice_result.dart';
import 'package:drift/drift.dart';

class ResultsService {
  final AppDatabase _db;

  // Session-only results for share dialog (cleared on app restart)
  final List<MemorizationResult> _sessionMemorizationResults = [];
  final List<RecitationResult> _sessionRecitationResults = [];

  ResultsService(this._db);

  // Session getters (for share dialog)
  List<MemorizationResult> get sessionMemorizationResults =>
      List.unmodifiable(_sessionMemorizationResults);

  List<RecitationResult> get sessionRecitationResults =>
      List.unmodifiable(_sessionRecitationResults);

  /// Add a memorization result to both session and persistent storage.
  Future<void> addMemorizationResult(MemorizationResult result) async {
    _sessionMemorizationResults.add(result);
    await _db.insertResult(
      ResultsCompanion.insert(
        timestamp: DateTime.now(),
        type: ResultType.memorization,
        bookId: result.ref.bookId!,
        startChapter: result.ref.chapterNumber!,
        startVerse: result.ref.verseNumber!,
        score: result.score,
        attempts: Value(result.attempts),
      ),
    );
  }

  /// Add a recitation result to both session and persistent storage.
  Future<void> addRecitationResult(RecitationResult result) async {
    _sessionRecitationResults.add(result);
    await _db.insertResult(
      ResultsCompanion.insert(
        timestamp: DateTime.now(),
        type: ResultType.recitation,
        bookId: result.ref.bookId,
        startChapter: result.ref.startChapter,
        startVerse: result.ref.startVerse,
        endChapter: Value(result.ref.endChapter),
        endVerse: Value(result.ref.endVerse),
        score: result.score,
      ),
    );
  }

  /// Clear session results only (persistent storage remains).
  void clearSession() {
    _sessionMemorizationResults.clear();
    _sessionRecitationResults.clear();
  }

  /// Get sections for the share dialog (session results only).
  List<ResultSection> getSections(BibleService bibleService) => [
        if (_sessionRecitationResults.isNotEmpty)
          ResultSection(
            title: 'Recitation',
            items: _sessionRecitationResults
                .map(
                  (result) => ResultItem(
                    score: result.starDisplay,
                    reference: bibleService.getRangeRefName(result.ref),
                  ),
                )
                .toList(),
          ),
        if (_sessionMemorizationResults.isNotEmpty)
          ResultSection(
            title: 'Memorization',
            items: _sessionMemorizationResults
                .map(
                  (result) => ResultItem(
                    score: result.scoreString,
                    reference: bibleService.getRefName(result.ref),
                  ),
                )
                .toList(),
          ),
      ];

  // Database access methods

  /// Get all results from persistent storage, newest first.
  Future<List<Result>> getAllResults() => _db.getAllResults();

  /// Watch all results (reactive stream).
  Stream<List<Result>> watchAllResults() => _db.watchAllResults();

  /// Get results for a specific verse.
  Future<List<Result>> getResultsForVerse(
    String bookId,
    int chapter,
    int verse,
  ) =>
      _db.getResultsForVerse(bookId, chapter, verse);

  /// Get unique verses that have been practiced.
  Future<List<({String bookId, int chapter, int verse})>>
      getUniqueVersesPracticed() => _db.getUniqueVersesPracticed();
}
