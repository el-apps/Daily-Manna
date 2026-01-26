import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/ui/memorization/practice_result.dart';
import 'package:daily_manna/ui/memorization/verse_memorization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('VerseMemorization', () {
    late _FakeBibleService fakeBibleService;
    late _FakeResultsService fakeResultsService;

    setUp(() {
      fakeBibleService = _FakeBibleService();
      fakeResultsService = _FakeResultsService();
    });

    Widget createTestWidget({ScriptureRef? initialRef}) => MultiProvider(
        providers: [
          Provider<BibleService>.value(value: fakeBibleService),
          Provider<ResultsService>.value(value: fakeResultsService),
        ],
        child: MaterialApp(
          home: VerseMemorization(initialRef: initialRef),
        ),
      );

    testWidgets('shows Try Again and Next buttons after correct answer',
        (tester) async {
      final ref = ScriptureRef(
        bookId: 'john',
        chapterNumber: 3,
        verseNumber: 16,
      );

      await tester.pumpWidget(createTestWidget(initialRef: ref));

      // Enter correct text
      await tester.enterText(find.byType(TextFormField), 'Test verse text');
      await tester.pump();

      // Submit
      await tester.tap(find.text('Submit'));
      await tester.pump();

      // Both buttons should be visible
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('Try Again resets to allow retry of same verse',
        (tester) async {
      final ref = ScriptureRef(
        bookId: 'john',
        chapterNumber: 3,
        verseNumber: 16,
      );

      await tester.pumpWidget(createTestWidget(initialRef: ref));

      // Enter correct text and submit
      await tester.enterText(find.byType(TextFormField), 'Test verse text');
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pump();

      // Tap Try Again
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      // Should be back to input state - no Try Again or Next buttons
      expect(find.text('Try Again'), findsNothing);
      expect(find.text('Next'), findsNothing);

      // Text field should be empty and ready for input
      final textField = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('Try Again keeps same verse reference', (tester) async {
      final ref = ScriptureRef(
        bookId: 'john',
        chapterNumber: 3,
        verseNumber: 16,
      );

      await tester.pumpWidget(createTestWidget(initialRef: ref));

      // Enter correct text and submit
      await tester.enterText(find.byType(TextFormField), 'Test verse text');
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pump();

      // Tap Try Again
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      // Enter text again and submit
      await tester.enterText(find.byType(TextFormField), 'Test verse text');
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pump();

      // Should still show Try Again and Next (same verse completed again)
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });
  });
}

class _FakeBibleService extends BibleService {
  @override
  bool hasVerse(ScriptureRef ref) => ref.complete;

  @override
  String getVerse(String bookId, int chapterNumber, int verseNumber) =>
      'Test verse text';

  @override
  String getRefName(ScriptureRef ref) =>
      '${ref.bookId} ${ref.chapterNumber}:${ref.verseNumber}';
}

class _FakeResultsService implements ResultsService {
  @override
  Future<void> addMemorizationResult(MemorizationResult result) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
