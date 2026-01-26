import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/services/spaced_repetition_service.dart';
import 'package:daily_manna/ui/memorization/practice_result.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late SpacedRepetitionService srService;
  late ResultsService resultsService;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    srService = SpacedRepetitionService(database);
    resultsService = ResultsService(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('SpacedRepetitionService streams', () {
    test('watchDueCount emits updated count when result is added', () async {
      // Start listening to the stream
      final counts = <int>[];
      final subscription = srService.watchDueCount().listen(counts.add);

      // Wait for initial emission
      await Future.delayed(const Duration(milliseconds: 100));
      expect(counts, contains(0)); // Should start with 0

      // Add a memorization result
      await resultsService.addMemorizationResult(
        MemorizationResult(
          ref: const ScriptureRef(
            bookId: 'Gen',
            chapterNumber: 1,
            verseNumber: 1,
          ),
          attempts: 1,
          score: 0.95,
        ),
      );

      // Wait for stream to emit
      await Future.delayed(const Duration(milliseconds: 100));

      // Should have emitted a new count (1 verse due tomorrow based on SM-2)
      expect(counts.length, greaterThan(1));
      // The verse is due tomorrow (interval = 1 day for first correct response)
      // so it won't be in "due today" count, but let's verify the stream emits
      
      await subscription.cancel();
    });

    test('watchVersesByReviewDate emits updated list when result is added', () async {
      final emissions = <List<VerseReviewState>>[];
      final subscription = srService.watchVersesByReviewDate().listen(emissions.add);

      // Wait for initial emission
      await Future.delayed(const Duration(milliseconds: 100));
      expect(emissions.last, isEmpty); // Should start empty

      // Add a memorization result
      await resultsService.addMemorizationResult(
        MemorizationResult(
          ref: const ScriptureRef(
            bookId: 'Gen',
            chapterNumber: 1,
            verseNumber: 1,
          ),
          attempts: 1,
          score: 0.95,
        ),
      );

      // Wait for stream to emit
      await Future.delayed(const Duration(milliseconds: 100));

      // Should have emitted a new list with 1 verse
      expect(emissions.length, greaterThan(1));
      expect(emissions.last.length, equals(1));
      expect(emissions.last.first.ref.bookId, equals('Gen'));
      expect(emissions.last.first.ref.chapterNumber, equals(1));
      expect(emissions.last.first.ref.verseNumber, equals(1));

      await subscription.cancel();
    });

    test('watchVersesByReviewDate emits on each new result', () async {
      final emissions = <List<VerseReviewState>>[];
      final subscription = srService.watchVersesByReviewDate().listen(emissions.add);

      // Wait for initial emission
      await Future.delayed(const Duration(milliseconds: 100));
      final initialCount = emissions.length;

      // Add first result
      await resultsService.addMemorizationResult(
        MemorizationResult(
          ref: const ScriptureRef(
            bookId: 'Gen',
            chapterNumber: 1,
            verseNumber: 1,
          ),
          attempts: 1,
          score: 0.95,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 100));

      // Add second result (different verse)
      await resultsService.addMemorizationResult(
        MemorizationResult(
          ref: const ScriptureRef(
            bookId: 'Gen',
            chapterNumber: 1,
            verseNumber: 2,
          ),
          attempts: 1,
          score: 0.90,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 100));

      // Should have emitted multiple times
      expect(emissions.length, greaterThan(initialCount + 1));
      // Last emission should have 2 verses
      expect(emissions.last.length, equals(2));

      await subscription.cancel();
    });
  });
}
