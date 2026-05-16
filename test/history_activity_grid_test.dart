import 'package:daily_manna/ui/history/history_activity_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HistoryActivityGrid helpers', () {
    test('normalizeActivityDays collapses multiple timestamps per day', () {
      final days = normalizeActivityDays([
        DateTime(2024, 5, 10, 9),
        DateTime(2024, 5, 10, 18),
        DateTime(2024, 5, 9, 12),
      ]);

      expect(days, {DateTime(2024, 5, 10), DateTime(2024, 5, 9)});
    });

    test('buildMonths returns month starts from newest to oldest', () {
      final months = buildMonths(
        firstDate: DateTime(2024, 5, 10),
        lastDate: DateTime(2024, 7, 2),
      );

      expect(months, [DateTime(2024, 7), DateTime(2024, 6), DateTime(2024, 5)]);
    });

    test('buildMonthCells pads the calendar grid to a full week', () {
      final cells = buildMonthCells(DateTime(2024, 6));

      expect(cells.length % 7, 0);
      expect(cells.first, isNull);
      expect(cells[6], DateTime(2024, 6, 1));
      expect(cells.last, isNull);
    });
  });

  group('HistoryActivityGrid', () {
    testWidgets('shows month navigation and checkmarks for the current month', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HistoryActivityGrid(
                activityDays: {DateTime(2024, 5, 8), DateTime(2024, 6, 10)},
                referenceDate: DateTime(2024, 6, 15, 15),
              ),
            ),
          ),
        ),
      );

      expect(find.text('June 2024'), findsOneWidget);

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(find.text('May 2024'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });
}
