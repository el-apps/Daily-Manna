import 'package:daily_manna/models/recitation_result.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/ui/memorization/practice_result.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ResultsService resultsService;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    resultsService = ResultsService(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('ResultsService', () {
    test('addMemorizationResult stores in session and database', () async {
      final result = MemorizationResult(
        ref: const ScriptureRef(
          bookId: 'Gen',
          chapterNumber: 1,
          verseNumber: 1,
        ),
        attempts: 1,
        score: 0.95,
      );

      await resultsService.addMemorizationResult(result);

      // Check session
      expect(resultsService.sessionMemorizationResults, hasLength(1));
      expect(resultsService.sessionMemorizationResults.first.score, 0.95);

      // Check database
      final dbResults = await resultsService.getAllResults();
      expect(dbResults, hasLength(1));
      expect(dbResults.first.type, ResultType.memorization);
      expect(dbResults.first.score, 0.95);
      expect(dbResults.first.attempts, 1);
    });

    test('addRecitationResult stores in session and database', () async {
      final result = RecitationResult(
        ref: const ScriptureRangeRef(
          bookId: 'Psa',
          startChapter: 23,
          startVerse: 1,
          endChapter: 23,
          endVerse: 6,
        ),
        score: 0.85,
      );

      await resultsService.addRecitationResult(result);

      // Check session
      expect(resultsService.sessionRecitationResults, hasLength(1));
      expect(resultsService.sessionRecitationResults.first.score, 0.85);

      // Check database
      final dbResults = await resultsService.getAllResults();
      expect(dbResults, hasLength(1));
      expect(dbResults.first.type, ResultType.recitation);
      expect(dbResults.first.endChapter, 23);
      expect(dbResults.first.endVerse, 6);
    });

    test('clearSession clears only session results', () async {
      await resultsService.addMemorizationResult(
        MemorizationResult(
          ref: const ScriptureRef(
            bookId: 'Gen',
            chapterNumber: 1,
            verseNumber: 1,
          ),
          attempts: 1,
          score: 0.9,
        ),
      );

      resultsService.clearSession();

      // Session should be empty
      expect(resultsService.sessionMemorizationResults, isEmpty);

      // Database should still have the result
      final dbResults = await resultsService.getAllResults();
      expect(dbResults, hasLength(1));
    });

    test('getResultsForVerse returns filtered results', () async {
      await resultsService.addMemorizationResult(
        MemorizationResult(
          ref: const ScriptureRef(
            bookId: 'Gen',
            chapterNumber: 1,
            verseNumber: 1,
          ),
          attempts: 1,
          score: 0.9,
        ),
      );
      await resultsService.addMemorizationResult(
        MemorizationResult(
          ref: const ScriptureRef(
            bookId: 'Gen',
            chapterNumber: 1,
            verseNumber: 2,
          ),
          attempts: 1,
          score: 0.8,
        ),
      );

      final results = await resultsService.getResultsForVerse('Gen', 1, 1);
      expect(results, hasLength(1));
      expect(results.first.startVerse, 1);
    });
  });
}
