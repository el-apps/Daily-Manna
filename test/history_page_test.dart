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
        ),
        db.Result(
          id: 2,
          timestamp: latest.subtract(const Duration(days: 1)),
          type: db.ResultType.recitation,
          bookId: 'Psa',
          startChapter: 23,
          startVerse: 1,
          score: 0.90,
        ),
      ];

      final filtered = filterResultsForDate(results, selectedDay);

      expect(filtered, hasLength(1));
      expect(filtered.single.id, 1);
      expect(filtered.single.timestamp.localDateOnly, selectedDay);
    });
  });
}
