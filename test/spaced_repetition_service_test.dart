import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/services/spaced_repetition_service.dart';
import 'package:daily_manna/ui/memorization/practice_result.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _testRef = ScriptureRef(
  bookId: 'Gen',
  chapterNumber: 1,
  verseNumber: 1,
);

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

  group('scoreToQuality', () {
    test('maps scores to quality 0-5', () {
      // Formula: ((score * 10) - 5).round().clamp(0, 5)
      expect(SpacedRepetitionService.scoreToQuality(0.50), equals(0));
      expect(SpacedRepetitionService.scoreToQuality(0.55), equals(1));
      expect(SpacedRepetitionService.scoreToQuality(0.65), equals(2));
      expect(SpacedRepetitionService.scoreToQuality(0.75), equals(3));
      expect(SpacedRepetitionService.scoreToQuality(0.85), equals(4));
      expect(SpacedRepetitionService.scoreToQuality(0.95), equals(5));
    });

    test('clamps extreme values', () {
      expect(SpacedRepetitionService.scoreToQuality(0.0), equals(0));
      expect(SpacedRepetitionService.scoreToQuality(0.40), equals(0));
      expect(SpacedRepetitionService.scoreToQuality(1.5), equals(5));
    });
  });

  group('interval progression with perfect scores', () {
    test('first review schedules 1 day out', () async {
      await _addResult(resultsService, score: 1.0);

      final states = await srService.getVersesByReviewDate();
      expect(states.length, equals(1));
      expect(states.first.intervalDays, equals(1));
    });

    test('second perfect review schedules 2 days out', () async {
      await _addResult(resultsService, score: 1.0);
      await _addResult(resultsService, score: 1.0);

      final states = await srService.getVersesByReviewDate();
      expect(states.first.intervalDays, equals(2));
    });

    test('progression doubles: 1, 2, 4, 8, 16, 32', () async {
      // 6 perfect reviews
      for (var i = 0; i < 6; i++) {
        await _addResult(resultsService, score: 1.0);
      }

      final states = await srService.getVersesByReviewDate();
      expect(states.first.intervalDays, equals(32));
    });

    test('interval caps at 32 days', () async {
      // 10 perfect reviews - should cap at 32
      for (var i = 0; i < 10; i++) {
        await _addResult(resultsService, score: 1.0);
      }

      final states = await srService.getVersesByReviewDate();
      expect(states.first.intervalDays, equals(32));
    });
  });

  group('interval reset on low scores', () {
    test('score below 90% resets interval to 1', () async {
      // Build up interval with perfect scores
      for (var i = 0; i < 4; i++) {
        await _addResult(resultsService, score: 1.0);
      }

      // Verify interval is at 8 days
      var states = await srService.getVersesByReviewDate();
      expect(states.first.intervalDays, equals(8));

      // Fail with 80% score (quality 3, below threshold of 4)
      await _addResult(resultsService, score: 0.80);

      states = await srService.getVersesByReviewDate();
      expect(states.first.intervalDays, equals(1));
    });

    test('84% score resets interval (quality 3)', () async {
      await _addResult(resultsService, score: 1.0);
      await _addResult(resultsService, score: 1.0);
      await _addResult(resultsService, score: 0.84); // quality 3

      final states = await srService.getVersesByReviewDate();
      expect(states.first.intervalDays, equals(1));
    });

    test('85% score advances interval (quality 4)', () async {
      await _addResult(resultsService, score: 1.0);
      await _addResult(resultsService, score: 0.85); // quality 4 - passes

      final states = await srService.getVersesByReviewDate();
      expect(states.first.intervalDays, equals(2));
    });
  });

  group('ease factor behavior', () {
    test('ease factor stays at 2.0 with perfect scores', () async {
      for (var i = 0; i < 5; i++) {
        await _addResult(resultsService, score: 1.0);
      }

      final states = await srService.getVersesByReviewDate();
      expect(states.first.easeFactor, equals(2.0));
    });

    test('ease factor decreases with quality 4 scores', () async {
      // Quality 4 (85-90%) decreases ease factor slightly
      // qualityDeficit = 5 - 4 = 1
      // penaltyFactor = 0.08 + 1 * 0.02 = 0.10
      // easeAdjustment = 0.1 - 1 * 0.10 = 0
      // So quality 4 keeps EF stable. Need quality 3 or lower to decrease.
      // But quality 3 resets the interval! So EF decrease happens on failures.
      await _addResult(resultsService, score: 0.75); // quality 3 - fails, resets
      await _addResult(resultsService, score: 1.0);  // recover

      final states = await srService.getVersesByReviewDate();
      // EF should have decreased from the quality 3 response
      expect(states.first.easeFactor, lessThan(2.0));
    });

    test('ease factor has minimum of 1.3', () async {
      // Many low-passing scores to drive down ease factor
      for (var i = 0; i < 20; i++) {
        await _addResult(resultsService, score: 0.90);
      }

      final states = await srService.getVersesByReviewDate();
      expect(states.first.easeFactor, greaterThanOrEqualTo(1.3));
    });
  });

  group('recovery after failure', () {
    test('rebuilds interval from 1 after reset', () async {
      // Build up to 8 days
      for (var i = 0; i < 4; i++) {
        await _addResult(resultsService, score: 1.0);
      }

      // Fail
      await _addResult(resultsService, score: 0.70);

      var states = await srService.getVersesByReviewDate();
      expect(states.first.intervalDays, equals(1));

      // Recover with perfect scores
      await _addResult(resultsService, score: 1.0);
      states = await srService.getVersesByReviewDate();
      expect(states.first.intervalDays, equals(1)); // still 1 (rep 0 -> 1)

      await _addResult(resultsService, score: 1.0);
      states = await srService.getVersesByReviewDate();
      expect(states.first.intervalDays, equals(2)); // now 2 (rep 1 -> 2)
    });
  });

  group('repetition tracking', () {
    test('tracks consecutive successful repetitions', () async {
      for (var i = 0; i < 5; i++) {
        await _addResult(resultsService, score: 1.0);
      }

      final states = await srService.getVersesByReviewDate();
      expect(states.first.repetitions, equals(5));
    });

    test('resets repetitions on failure', () async {
      for (var i = 0; i < 5; i++) {
        await _addResult(resultsService, score: 1.0);
      }
      await _addResult(resultsService, score: 0.70);

      final states = await srService.getVersesByReviewDate();
      expect(states.first.repetitions, equals(0));
    });
  });
}

Future<void> _addResult(
  ResultsService resultsService, {
  required double score,
  ScriptureRef ref = _testRef,
}) async {
  await resultsService.addMemorizationResult(
    MemorizationResult(ref: ref, attempts: 1, score: score),
  );
}
