import 'package:daily_manna/utils/date_utils.dart';
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

    test('normalizeActivityDays uses local days for UTC timestamps', () {
      final timestamp = DateTime.utc(2024, 1, 16, 3);
      final days = normalizeActivityDays([timestamp]);

      expect(days, {timestamp.toLocal().dateOnly});
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
    testWidgets('opens on the selected month instead of the newest month', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HistoryActivityGrid(
                activityDays: {DateTime(2024, 3, 9), DateTime(2024, 5, 10)},
                selectedDate: DateTime(2024, 3, 9),
                onDateSelected: (_) {},
                referenceDate: DateTime(2024, 5, 15, 15),
              ),
            ),
          ),
        ),
      );

      expect(find.text('March 2024'), findsOneWidget);
    });

    testWidgets('month navigation updates the selected date to that month', (
      tester,
    ) async {
      DateTime selectedDate = DateTime(2024, 6, 10);

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: SingleChildScrollView(
                child: HistoryActivityGrid(
                  activityDays: {DateTime(2024, 5, 8), DateTime(2024, 6, 10)},
                  selectedDate: selectedDate,
                  onDateSelected: (date) =>
                      setState(() => selectedDate = date.dateOnly),
                  referenceDate: DateTime(2024, 6, 15, 15),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(find.text('May 2024'), findsOneWidget);
      expect(selectedDate, DateTime(2024, 5, 1));
    });

    testWidgets('shows month navigation and checkmarks for the current month', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HistoryActivityGrid(
                activityDays: {DateTime(2024, 5, 8), DateTime(2024, 6, 10)},
                selectedDate: DateTime(2024, 6, 10),
                onDateSelected: (_) {},
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

    testWidgets('tapping a day reports the selected date', (tester) async {
      DateTime? selectedDate;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HistoryActivityGrid(
                activityDays: {DateTime(2024, 6, 14)},
                selectedDate: DateTime(2024, 6, 15),
                onDateSelected: (date) => selectedDate = date,
                referenceDate: DateTime(2024, 6, 15, 15),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('14'));
      await tester.pump();

      expect(selectedDate, DateTime(2024, 6, 14));
    });
  });
}
