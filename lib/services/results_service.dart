import 'package:daily_manna/models/recitation_result.dart';
import 'package:daily_manna/models/result_item.dart';
import 'package:daily_manna/models/result_section.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/ui/memorization/interact_result.dart';
import 'package:drift/drift.dart';

class ResultsService {
  final AppDatabase _db;
  Future<void> Function()? onLocalChange;

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
    await onLocalChange?.call();
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
    await onLocalChange?.call();
  }

  /// Add a study result through the same tracked local-write path.
  Future<void> addStudyResult(ScriptureRangeRef ref, {String? notes}) async {
    await _db.insertResult(
      ResultsCompanion.insert(
        timestamp: DateTime.now(),
        type: ResultType.study,
        bookId: ref.bookId,
        startChapter: ref.chapter,
        startVerse: ref.startVerse,
        endVerse: Value(ref.endVerse),
        score: 1,
        notes: Value(notes),
      ),
    );
    await onLocalChange?.call();
  }

  Future<void> updateNotes(int id, String? notes) async {
    await _db.updateResultNotes(id, notes);
    await onLocalChange?.call();
  }

  /// Get sections for the share dialog (today's results only).
  ///
  /// Results are ordered by interaction time (first to last). Consecutive results
  /// of the same type are grouped into a single section.
  Future<List<ResultSection>> getTodaySections(
    BibleService bibleService,
  ) async {
    final results = await _db.getTodayResults();
    if (results.isEmpty) return [];

    // Reverse to get chronological order (first interacted with to last)
    final chronological = results.reversed.toList();

    final sections = <ResultSection>[];
    ResultType? currentType;
    var currentItems = <ResultItem>[];

    for (final r in chronological) {
      if (r.type != currentType) {
        // Save previous section if it has items
        if (currentItems.isNotEmpty) {
          sections.add(
            ResultSection(
              title: _typeToTitle(currentType!),
              items: currentItems,
            ),
          );
        }
        // Start new section
        currentType = r.type;
        currentItems = [];
      }

      currentItems.add(_resultToItem(r, bibleService));
    }

    // Add final section
    if (currentItems.isNotEmpty) {
      sections.add(
        ResultSection(title: _typeToTitle(currentType!), items: currentItems),
      );
    }

    return sections;
  }

  String _typeToTitle(ResultType type) => switch (type) {
    ResultType.memorization => 'Memorization',
    ResultType.recitation => 'Recitation',
    ResultType.study => 'Study',
  };

  ResultItem _resultToItem(Result r, BibleService bibleService) {
    final reference = r.type == ResultType.memorization
        ? bibleService.getRefName(
            ScriptureRef(
              bookId: r.bookId,
              chapterNumber: r.startChapter,
              verseNumber: r.startVerse,
            ),
          )
        : bibleService.getRangeRefName(_toRangeRef(r));

    return ResultItem(
      score: r.score,
      attempts: r.attempts ?? 1,
      reference: reference,
      notes: r.notes,
    );
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

  /// Get unique verses that have been interacted with.
  Future<List<({String bookId, int chapter, int verse})>>
  getUniqueVersesInteracted() => _db.getUniqueVersesInteracted();

  /// Get today's results.
  Future<List<Result>> getTodayResults() => _db.getTodayResults();
}
