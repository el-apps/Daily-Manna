import 'package:daily_manna/models/recitation_result.dart';
import 'package:daily_manna/models/result_item.dart';
import 'package:daily_manna/models/result_section.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/ui/memorization/practice_result.dart';
import 'package:drift/drift.dart';

class ResultsService {
  final AppDatabase _db;

  ResultsService(this._db);

  /// Add a memorization result to persistent storage.
  Future<void> addMemorizationResult(MemorizationResult result) async {
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

  /// Add a recitation result to persistent storage.
  Future<void> addRecitationResult(RecitationResult result) async {
    await _db.insertResult(
      ResultsCompanion.insert(
        timestamp: DateTime.now(),
        type: ResultType.recitation,
        bookId: result.ref.bookId,
        startChapter: result.ref.chapter,
        startVerse: result.ref.startVerse,
        endVerse: Value(result.ref.endVerse),
        score: result.score,
      ),
    );
  }

  /// Get sections for the share dialog (today's results only).
  Future<List<ResultSection>> getTodaySections(
    BibleService bibleService,
  ) async {
    final results = await _db.getTodayResults();

    final recitationResults = results
        .where((r) => r.type == ResultType.recitation)
        .toList();
    final memorizationResults = results
        .where((r) => r.type == ResultType.memorization)
        .toList();

    return [
      if (recitationResults.isNotEmpty)
        ResultSection(
          title: 'Recitation',
          items: recitationResults
              .map(
                (r) => ResultItem(
                  score: RecitationResult(
                    ref: _toRangeRef(r),
                    score: r.score,
                  ).scoreDisplay,
                  reference: bibleService.getRangeRefName(_toRangeRef(r)),
                ),
              )
              .toList(),
        ),
      if (memorizationResults.isNotEmpty)
        ResultSection(
          title: 'Memorization',
          items: memorizationResults
              .map(
                (r) => ResultItem(
                  score: MemorizationResult(
                    ref: ScriptureRef(
                      bookId: r.bookId,
                      chapterNumber: r.startChapter,
                      verseNumber: r.startVerse,
                    ),
                    attempts: r.attempts ?? 1,
                    score: r.score,
                  ).scoreString,
                  reference: bibleService.getRefName(
                    ScriptureRef(
                      bookId: r.bookId,
                      chapterNumber: r.startChapter,
                      verseNumber: r.startVerse,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
    ];
  }

  ScriptureRangeRef _toRangeRef(Result r) => ScriptureRangeRef(
        bookId: r.bookId,
        chapter: r.startChapter,
        startVerse: r.startVerse,
        endVerse: r.endVerse,
      );

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
  ) => _db.getResultsForVerse(bookId, chapter, verse);

  /// Get unique verses that have been practiced.
  Future<List<({String bookId, int chapter, int verse})>>
  getUniqueVersesPracticed() => _db.getUniqueVersesPracticed();

  /// Get today's results.
  Future<List<Result>> getTodayResults() => _db.getTodayResults();
}
