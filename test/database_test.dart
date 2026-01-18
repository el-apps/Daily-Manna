import 'package:daily_manna/services/database/database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('Results table', () {
    test('inserts and retrieves a memorization result', () async {
      final result = ResultsCompanion.insert(
        timestamp: DateTime(2024, 1, 15, 10, 30),
        type: ResultType.memorization,
        bookId: 'Gen',
        startChapter: 1,
        startVerse: 1,
        score: 0.95,
        attempts: const Value(1),
      );

      final id = await database.insertResult(result);
      expect(id, greaterThan(0));

      final results = await database.getAllResults();
      expect(results, hasLength(1));
      expect(results.first.bookId, 'Gen');
      expect(results.first.score, 0.95);
      expect(results.first.type, ResultType.memorization);
    });

    test('inserts and retrieves a recitation result', () async {
      final result = ResultsCompanion.insert(
        timestamp: DateTime(2024, 1, 15, 10, 30),
        type: ResultType.recitation,
        bookId: 'Psa',
        startChapter: 23,
        startVerse: 1,
        endChapter: const Value(23),
        endVerse: const Value(6),
        score: 0.85,
      );

      await database.insertResult(result);

      final results = await database.getAllResults();
      expect(results, hasLength(1));
      expect(results.first.bookId, 'Psa');
      expect(results.first.endChapter, 23);
      expect(results.first.endVerse, 6);
      expect(results.first.type, ResultType.recitation);
    });

    test('getResultsForVerse filters correctly', () async {
      // Insert multiple results
      await database.insertResult(
        ResultsCompanion.insert(
          timestamp: DateTime(2024, 1, 15),
          type: ResultType.memorization,
          bookId: 'Gen',
          startChapter: 1,
          startVerse: 1,
          score: 0.9,
        ),
      );
      await database.insertResult(
        ResultsCompanion.insert(
          timestamp: DateTime(2024, 1, 16),
          type: ResultType.memorization,
          bookId: 'Gen',
          startChapter: 1,
          startVerse: 2,
          score: 0.8,
        ),
      );
      await database.insertResult(
        ResultsCompanion.insert(
          timestamp: DateTime(2024, 1, 17),
          type: ResultType.memorization,
          bookId: 'Gen',
          startChapter: 1,
          startVerse: 1,
          score: 0.95,
        ),
      );

      final results = await database.getResultsForVerse('Gen', 1, 1);
      expect(results, hasLength(2));
      expect(results.every((r) => r.startVerse == 1), isTrue);
    });

    test('getAllResults returns newest first', () async {
      await database.insertResult(
        ResultsCompanion.insert(
          timestamp: DateTime(2024, 1, 15),
          type: ResultType.memorization,
          bookId: 'Gen',
          startChapter: 1,
          startVerse: 1,
          score: 0.9,
        ),
      );
      await database.insertResult(
        ResultsCompanion.insert(
          timestamp: DateTime(2024, 1, 17),
          type: ResultType.memorization,
          bookId: 'Gen',
          startChapter: 1,
          startVerse: 2,
          score: 0.8,
        ),
      );
      await database.insertResult(
        ResultsCompanion.insert(
          timestamp: DateTime(2024, 1, 16),
          type: ResultType.memorization,
          bookId: 'Gen',
          startChapter: 1,
          startVerse: 3,
          score: 0.7,
        ),
      );

      final results = await database.getAllResults();
      expect(results[0].timestamp, DateTime(2024, 1, 17));
      expect(results[1].timestamp, DateTime(2024, 1, 16));
      expect(results[2].timestamp, DateTime(2024, 1, 15));
    });

    test('getUniqueVersesPracticed returns distinct verses', () async {
      // Same verse practiced twice
      await database.insertResult(
        ResultsCompanion.insert(
          timestamp: DateTime(2024, 1, 15),
          type: ResultType.memorization,
          bookId: 'Gen',
          startChapter: 1,
          startVerse: 1,
          score: 0.9,
        ),
      );
      await database.insertResult(
        ResultsCompanion.insert(
          timestamp: DateTime(2024, 1, 16),
          type: ResultType.memorization,
          bookId: 'Gen',
          startChapter: 1,
          startVerse: 1,
          score: 0.95,
        ),
      );
      // Different verse
      await database.insertResult(
        ResultsCompanion.insert(
          timestamp: DateTime(2024, 1, 17),
          type: ResultType.memorization,
          bookId: 'Psa',
          startChapter: 23,
          startVerse: 1,
          score: 0.8,
        ),
      );

      final verses = await database.getUniqueVersesPracticed();
      expect(verses, hasLength(2));
    });
  });
}
