import 'package:daily_manna/models/recitation_result.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/ui/memorization/practice_result.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal BibleService for testing that returns predictable reference names.
class FakeBibleService extends BibleService {
  @override
  getRefName(ScriptureRef ref) =>
      '${ref.bookId} ${ref.chapterNumber}:${ref.verseNumber}';

  @override
  String getRangeRefName(ScriptureRangeRef ref) {
    if (ref.endVerse == null || ref.endVerse == ref.startVerse) {
      return '${ref.bookId} ${ref.chapter}:${ref.startVerse}';
    }
    return '${ref.bookId} ${ref.chapter}:${ref.startVerse}-${ref.endVerse}';
  }
}

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
    test('addMemorizationResult stores in database', () async {
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

      final dbResults = await resultsService.getAllResults();
      expect(dbResults, hasLength(1));
      expect(dbResults.first.type, ResultType.memorization);
      expect(dbResults.first.score, 0.95);
      expect(dbResults.first.attempts, 1);
    });

    test('addRecitationResult stores in database', () async {
      final result = RecitationResult(
        ref: const ScriptureRangeRef(
          bookId: 'Psa',
          chapter: 23,
          startVerse: 1,
          endVerse: 6,
        ),
        score: 0.85,
      );

      await resultsService.addRecitationResult(result);

      final dbResults = await resultsService.getAllResults();
      expect(dbResults, hasLength(1));
      expect(dbResults.first.type, ResultType.recitation);
      expect(dbResults.first.startChapter, 23);
      expect(dbResults.first.endVerse, 6);
    });

    test('getTodayResults returns only results from today', () async {
      // This result is from today
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

      final todayResults = await resultsService.getTodayResults();
      expect(todayResults, hasLength(1));
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

    test('getTodaySections returns empty list when no results', () async {
      final sections = await resultsService.getTodaySections(
        FakeBibleService(),
      );
      expect(sections, isEmpty);
    });

    test('getTodaySections with single memorization result', () async {
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

      final sections = await resultsService.getTodaySections(
        FakeBibleService(),
      );

      expect(sections, hasLength(1));
      expect(sections[0].title, 'Memorization');
      expect(sections[0].items, hasLength(1));
      expect(sections[0].items[0].reference, 'Gen 1:1');
      expect(sections[0].items[0].score, 0.9);
    });

    test('getTodaySections with single recitation result', () async {
      await resultsService.addRecitationResult(
        RecitationResult(
          ref: const ScriptureRangeRef(
            bookId: 'Psa',
            chapter: 23,
            startVerse: 1,
            endVerse: 6,
          ),
          score: 0.85,
        ),
      );

      final sections = await resultsService.getTodaySections(
        FakeBibleService(),
      );

      expect(sections, hasLength(1));
      expect(sections[0].title, 'Recitation');
      expect(sections[0].items, hasLength(1));
      expect(sections[0].items[0].reference, 'Psa 23:1-6');
      expect(sections[0].items[0].score, 0.85);
    });

    test('getTodaySections with all memorization results', () async {
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
          attempts: 2,
          score: 0.85,
        ),
      );
      await resultsService.addMemorizationResult(
        MemorizationResult(
          ref: const ScriptureRef(
            bookId: 'John',
            chapterNumber: 3,
            verseNumber: 16,
          ),
          attempts: 1,
          score: 0.95,
        ),
      );

      final sections = await resultsService.getTodaySections(
        FakeBibleService(),
      );

      // All same type should be in one section
      expect(sections, hasLength(1));
      expect(sections[0].title, 'Memorization');
      expect(sections[0].items, hasLength(3));
      expect(sections[0].items[0].reference, 'Gen 1:1');
      expect(sections[0].items[1].reference, 'Gen 1:2');
      expect(sections[0].items[2].reference, 'John 3:16');
    });

    test('getTodaySections with all recitation results', () async {
      await resultsService.addRecitationResult(
        RecitationResult(
          ref: const ScriptureRangeRef(
            bookId: 'Psa',
            chapter: 23,
            startVerse: 1,
            endVerse: 6,
          ),
          score: 0.85,
        ),
      );
      await resultsService.addRecitationResult(
        RecitationResult(
          ref: const ScriptureRangeRef(
            bookId: 'Psa',
            chapter: 100,
            startVerse: 1,
            endVerse: 5,
          ),
          score: 0.9,
        ),
      );

      final sections = await resultsService.getTodaySections(
        FakeBibleService(),
      );

      expect(sections, hasLength(1));
      expect(sections[0].title, 'Recitation');
      expect(sections[0].items, hasLength(2));
      expect(sections[0].items[0].reference, 'Psa 23:1-6');
      expect(sections[0].items[1].reference, 'Psa 100:1-5');
    });

    test(
      'getTodaySections preserves practice order with alternating types',
      () async {
        // Add results in specific order: memorization, recitation, memorization
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
        await resultsService.addRecitationResult(
          RecitationResult(
            ref: const ScriptureRangeRef(
              bookId: 'Psa',
              chapter: 23,
              startVerse: 1,
              endVerse: 6,
            ),
            score: 0.85,
          ),
        );
        await resultsService.addMemorizationResult(
          MemorizationResult(
            ref: const ScriptureRef(
              bookId: 'John',
              chapterNumber: 3,
              verseNumber: 16,
            ),
            attempts: 2,
            score: 0.95,
          ),
        );

        final sections = await resultsService.getTodaySections(
          FakeBibleService(),
        );

        // Should have 3 sections (type changes each time)
        expect(sections, hasLength(3));
        expect(sections[0].title, 'Memorization');
        expect(sections[0].items, hasLength(1));
        expect(sections[0].items[0].reference, 'Gen 1:1');

        expect(sections[1].title, 'Recitation');
        expect(sections[1].items, hasLength(1));
        expect(sections[1].items[0].reference, 'Psa 23:1-6');

        expect(sections[2].title, 'Memorization');
        expect(sections[2].items, hasLength(1));
        expect(sections[2].items[0].reference, 'John 3:16');
      },
    );

    test('getTodaySections collapses consecutive same-type results', () async {
      // Add two memorizations, then two recitations
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
          score: 0.85,
        ),
      );
      await resultsService.addRecitationResult(
        RecitationResult(
          ref: const ScriptureRangeRef(
            bookId: 'Psa',
            chapter: 23,
            startVerse: 1,
            endVerse: 6,
          ),
          score: 0.95,
        ),
      );
      await resultsService.addRecitationResult(
        RecitationResult(
          ref: const ScriptureRangeRef(
            bookId: 'Psa',
            chapter: 100,
            startVerse: 1,
            endVerse: 5,
          ),
          score: 0.88,
        ),
      );

      final sections = await resultsService.getTodaySections(
        FakeBibleService(),
      );

      // Should have 2 sections (consecutive same-types collapsed)
      expect(sections, hasLength(2));

      expect(sections[0].title, 'Memorization');
      expect(sections[0].items, hasLength(2));
      expect(sections[0].items[0].reference, 'Gen 1:1');
      expect(sections[0].items[1].reference, 'Gen 1:2');

      expect(sections[1].title, 'Recitation');
      expect(sections[1].items, hasLength(2));
      expect(sections[1].items[0].reference, 'Psa 23:1-6');
      expect(sections[1].items[1].reference, 'Psa 100:1-5');
    });

    test('getTodaySections with complex pattern of types', () async {
      // Pattern: mem, mem, rec, mem, rec, rec, mem
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
          score: 0.85,
        ),
      );
      await resultsService.addRecitationResult(
        RecitationResult(
          ref: const ScriptureRangeRef(
            bookId: 'Psa',
            chapter: 23,
            startVerse: 1,
            endVerse: 6,
          ),
          score: 0.95,
        ),
      );
      await resultsService.addMemorizationResult(
        MemorizationResult(
          ref: const ScriptureRef(
            bookId: 'John',
            chapterNumber: 3,
            verseNumber: 16,
          ),
          attempts: 2,
          score: 0.88,
        ),
      );
      await resultsService.addRecitationResult(
        RecitationResult(
          ref: const ScriptureRangeRef(
            bookId: 'Rom',
            chapter: 8,
            startVerse: 1,
            endVerse: 4,
          ),
          score: 0.92,
        ),
      );
      await resultsService.addRecitationResult(
        RecitationResult(
          ref: const ScriptureRangeRef(
            bookId: 'Rom',
            chapter: 8,
            startVerse: 28,
            endVerse: 30,
          ),
          score: 0.87,
        ),
      );
      await resultsService.addMemorizationResult(
        MemorizationResult(
          ref: const ScriptureRef(
            bookId: 'Eph',
            chapterNumber: 2,
            verseNumber: 8,
          ),
          attempts: 1,
          score: 0.99,
        ),
      );

      final sections = await resultsService.getTodaySections(
        FakeBibleService(),
      );

      // Should have 5 sections: [mem,mem], [rec], [mem], [rec,rec], [mem]
      expect(sections, hasLength(5));

      expect(sections[0].title, 'Memorization');
      expect(sections[0].items, hasLength(2));

      expect(sections[1].title, 'Recitation');
      expect(sections[1].items, hasLength(1));

      expect(sections[2].title, 'Memorization');
      expect(sections[2].items, hasLength(1));

      expect(sections[3].title, 'Recitation');
      expect(sections[3].items, hasLength(2));

      expect(sections[4].title, 'Memorization');
      expect(sections[4].items, hasLength(1));
    });

    test('getTodaySections preserves scores correctly', () async {
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
      await resultsService.addRecitationResult(
        RecitationResult(
          ref: const ScriptureRangeRef(
            bookId: 'Psa',
            chapter: 23,
            startVerse: 1,
            endVerse: 6,
          ),
          score: 0.72,
        ),
      );

      final sections = await resultsService.getTodaySections(
        FakeBibleService(),
      );

      expect(sections[0].items[0].score, 0.95);
      expect(sections[1].items[0].score, 0.72);
    });

    test('getTodaySections preserves attempts for memorization', () async {
      await resultsService.addMemorizationResult(
        MemorizationResult(
          ref: const ScriptureRef(
            bookId: 'Gen',
            chapterNumber: 1,
            verseNumber: 1,
          ),
          attempts: 3,
          score: 0.95,
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
          score: 0.88,
        ),
      );

      final sections = await resultsService.getTodaySections(
        FakeBibleService(),
      );

      expect(sections[0].items[0].attempts, 3);
      expect(sections[0].items[1].attempts, 1);
    });

    test('getTodaySections defaults attempts to 1 for recitation', () async {
      await resultsService.addRecitationResult(
        RecitationResult(
          ref: const ScriptureRangeRef(
            bookId: 'Psa',
            chapter: 23,
            startVerse: 1,
            endVerse: 6,
          ),
          score: 0.85,
        ),
      );

      final sections = await resultsService.getTodaySections(
        FakeBibleService(),
      );

      expect(sections[0].items[0].attempts, 1);
    });

    test(
      'getTodaySections formats single verse recitation reference',
      () async {
        await resultsService.addRecitationResult(
          RecitationResult(
            ref: const ScriptureRangeRef(
              bookId: 'John',
              chapter: 3,
              startVerse: 16,
            ),
            score: 0.9,
          ),
        );

        final sections = await resultsService.getTodaySections(
          FakeBibleService(),
        );

        expect(sections[0].items[0].reference, 'John 3:16');
      },
    );

    test(
      'getTodaySections formats single verse when endVerse equals startVerse',
      () async {
        await resultsService.addRecitationResult(
          RecitationResult(
            ref: const ScriptureRangeRef(
              bookId: 'John',
              chapter: 3,
              startVerse: 16,
              endVerse: 16,
            ),
            score: 0.9,
          ),
        );

        final sections = await resultsService.getTodaySections(
          FakeBibleService(),
        );

        expect(sections[0].items[0].reference, 'John 3:16');
      },
    );
  });
}
