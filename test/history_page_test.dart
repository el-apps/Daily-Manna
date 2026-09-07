import 'package:daily_manna/services/database/database.dart' as db;
import 'package:daily_manna/ui/history/history_page.dart';
import 'package:daily_manna/utils/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('filterResultsForDate', () {
    test('returns only results that fall on the selected local day', () {
      final latest = DateTime.utc(2024, 1, 16, 3);
      final selectedDay = latest.toLocal().dateOnly;

      final results = [
        db.Result(
          id: 1,
          timestamp: latest,
          type: db.ResultType.memorization,
          bookId: 'Gen',
          startChapter: 1,
          startVerse: 1,
          score: 0.95,
          clientId: 'result-1',
          updatedAt: latest,
        ),
        db.Result(
          id: 2,
          timestamp: latest.subtract(const Duration(days: 1)),
          type: db.ResultType.recitation,
          bookId: 'Psa',
          startChapter: 23,
          startVerse: 1,
          score: 0.90,
          clientId: 'result-2',
          updatedAt: latest.subtract(const Duration(days: 1)),
        ),
      ];

      final filtered = filterResultsForDate(results, selectedDay);

      expect(filtered, hasLength(1));
      expect(filtered.single.id, 1);
      expect(filtered.single.timestamp.localDateOnly, selectedDay);
    });
  });

  group('filterResultsByType', () {
    final results = [
      db.Result(
        id: 1,
        timestamp: DateTime(2024, 1, 1),
        type: db.ResultType.study,
        bookId: 'Gen',
        startChapter: 1,
        startVerse: 1,
        score: 1,
        clientId: 'study',
        updatedAt: DateTime(2024, 1, 1),
      ),
      db.Result(
        id: 2,
        timestamp: DateTime(2024, 1, 2),
        type: db.ResultType.memorization,
        bookId: 'Gen',
        startChapter: 1,
        startVerse: 2,
        score: 1,
        clientId: 'memorization',
        updatedAt: DateTime(2024, 1, 2),
      ),
    ];

    test('returns all results for the All filter', () {
      expect(filterResultsByType(results, null), same(results));
    });

    test('returns only study sessions for the Study filter', () {
      final filtered = filterResultsByType(results, db.ResultType.study);
      expect(filtered.map((result) => result.id), [1]);
    });

    test('returns only practice results for a practice filter', () {
      final filtered = filterResultsByType(results, db.ResultType.memorization);
      expect(filtered.map((result) => result.id), [2]);
    });
  });
}
