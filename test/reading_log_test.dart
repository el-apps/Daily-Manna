import 'dart:io';

import 'package:bible_parser_flutter/bible_parser_flutter.dart';
import 'package:daily_manna/home_page.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/services/reading_reference_parser.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/services/spaced_repetition_service.dart';
import 'package:daily_manna/services/streak_service.dart';
import 'package:daily_manna/ui/verse_selection/reference_tab.dart';
import 'package:daily_manna/ui/verse_selection/verse_selection_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Bible extends BibleService {
  _Bible(this.books);
  @override
  final List<Book> books;
  @override
  Map<String, Book> get booksMap => {for (final b in books) b.id: b};
  @override
  List<Chapter> getChapters(String id) => booksMap[id]!.chapters;
  @override
  String getRangeRefName(ScriptureRangeRef ref) =>
      '${booksMap[ref.bookId]!.title} ${ref.chapter}:${ref.startVerse}';
}

void main() {
  late _Bible bible;
  late ReadingReferenceParser parser;
  setUpAll(() async {
    final xml = File('assets/kjv.xml').readAsStringSync();
    bible = _Bible(
      await BibleParser.fromString(xml, format: 'OSIS').books.toList(),
    );
    parser = ReadingReferenceParser(bible);
  });

  List<String> labels(String input) => parser
      .parse(input)
      .map(
        (p) => bible.getReadingName(
          bookId: p.bookId,
          startChapter: p.startChapter,
          startVerse: p.startVerse,
          endChapter: p.endChapter,
          endVerse: p.endVerse,
        ),
      )
      .toList();

  test(
    'whole chapters resolve to real endpoints without knowing the last verse',
    () {
      final p = parser.parse('DEUT.1 - 4').single;
      expect(
        (p.startChapter, p.startVerse, p.endChapter, p.endVerse),
        (1, 1, 4, 49),
      );
      expect(labels('deut 1–4'), ['Deuteronomy 1–4']);
      expect(labels('Psalm 23'), ['Psalms 23']);
    },
  );

  test(
    'chapter and verse lists inherit the right context and reset at new books',
    () {
      expect(labels('John 1,3'), ['John 1', 'John 3']);
      expect(labels('John 3:16,18–20; 4'), [
        'John 3:16',
        'John 3:18–20',
        'John 4',
      ]);
      expect(labels('John 3:16, Romans 8,10'), [
        'John 3:16',
        'Romans 8',
        'Romans 10',
      ]);
      expect(labels('John 1,1'), ['John 1']);
    },
  );

  test(
    'flexible abbreviations include numbered books, periods, and prefixes',
    () {
      for (final input in [
        '1 jhn 2',
        '1JHN2',
        'I John 2',
        '1 jn. 2',
        '1 jo 2',
      ]) {
        expect(labels(input), ['1 John 2'], reason: input);
      }
      expect(labels('jhn 3:16, lk 4:2'), ['John 3:16', 'Luke 4:2']);
      expect(labels('Deuter 2'), ['Deuteronomy 2']);
    },
  );

  test('cross-chapter and mixed ranges retain both endpoints', () {
    expect(labels('John 3:16–4:12'), ['John 3:16–4:12']);
    expect(labels('John 3–4:12'), ['John 3:1–4:12']);
    expect(labels('John 1:5–2:5'), ['John 1:5–2:5']);
  });

  test(
    'ambiguity, partial input and invalid passages reject the entire submission',
    () {
      for (final input in [
        'Jo 1',
        'John 22',
        'John 3:37',
        'John 4:2–3:9',
        'John 0',
        'John 3:0',
        'John 1,',
        'John 1,,3',
        'John 1; bogus',
        'John 1,999',
      ]) {
        expect(() => parser.parse(input), throwsFormatException, reason: input);
      }
      expect(labels('John 3:36'), ['John 3:36']);
      expect(labels('John 3:16;4'), ['John 3:16', 'John 4']);
    },
  );

  test(
    'one reading submission persists complete passages and share labels',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final results = ResultsService(db);
      await results.addReading(parser.parse('Deut 1–4, 1 jhn 2'));
      final stored = await results.getAllResults();
      expect(stored, hasLength(2));
      final deut = stored.firstWhere((r) => r.startChapter == 1);
      expect((deut.startVerse, deut.endChapter, deut.endVerse), (1, 4, 49));
      expect(
        stored.every(
          (r) => r.type == ResultType.study && r.studyNoteId == null,
        ),
        isTrue,
      );
      expect(await db.select(db.syncOutbox).get(), hasLength(2));
      final sections = await results.getTodaySections(bible);
      expect(
        sections.single.items.map((i) => i.reference),
        containsAll(['Deuteronomy 1–4', '1 John 2']),
      );
    },
  );

  testWidgets('live preview enables logging only when every passage is valid', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<BibleService>.value(value: bible),
          Provider(create: (_) => ResultsService(db)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ReferenceTab(
              onSelected: (_) {},
              onLogReading: ResultsService(db).addReading,
            ),
          ),
        ),
      ),
    );
    final save = find.widgetWithText(FilledButton, 'Log reading');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'John 1,3');
    await tester.pump();
    expect(find.text('John 1'), findsOneWidget);
    expect(find.text('John 3'), findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.enterText(find.byType(TextField), 'John 1,999');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(await db.getAllResults(), isEmpty);
    await tester.enterText(find.byType(TextField), '1 jhn 2');
    await tester.pump();
    expect(find.text('1 John 2'), findsOneWidget);
  });

  Widget host(AppDatabase db, Widget home) => MultiProvider(
    providers: [
      Provider<BibleService>.value(value: bible),
      Provider<AppDatabase>.value(value: db),
      Provider(create: (_) => ResultsService(db)),
      Provider(create: (_) => StreakService(db)),
      Provider(create: (_) => SpacedRepetitionService(db)),
    ],
    child: MaterialApp(home: home),
  );

  testWidgets(
    'Interact offers logging in Reference, closes after save, and keeps browsing',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(() => db.getAllResults());
      await tester.pumpWidget(host(db, const HomePage()));
      await tester.pumpAndSettle();
      expect(find.text('Log reading'), findsNothing);
      await tester.tap(find.text('Interact'));
      await tester.pumpAndSettle();
      expect(find.text('Reference'), findsOneWidget);
      expect(find.byType(ReferenceTab), findsOneWidget);
      expect(find.byType(ActionChip), findsNothing);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.enterText(find.byType(TextField), 'Deut 1–4');
      await tester.pump();
      expect(find.text('Deuteronomy 1–4'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Log reading'));
      });
      // Let real database work and Flutter's fake-async callbacks both advance.
      for (
        var attempt = 0;
        attempt < 100 && find.byType(ReferenceTab).evaluate().isNotEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      expect(find.byType(ReferenceTab), findsNothing);
      expect(find.text('Memorize'), findsNothing);
      await tester.runAsync(() async {
        expect((await db.getAllResults()).single.endChapter, 4);
      });
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(ReferenceTab), findsOneWidget);
      await tester.tap(find.text('Books'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deuteronomy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select entire chapter'));
      await tester.pumpAndSettle();
      expect(find.text('Memorize'), findsOneWidget);
      expect(find.text('Recite'), findsOneWidget);
      expect(find.text('Study'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('shared passage selectors return typed ranges without logging', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    ScriptureRangeRef? selected;
    await tester.pumpWidget(
      host(
        db,
        Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                selected = await showPassageSelector(context);
              },
              child: const Text('Choose passage'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose passage'));
    await tester.pumpAndSettle();
    expect(find.text('Reading'), findsNothing);
    expect(find.text('Reference'), findsOneWidget);
    expect(find.byType(ReferenceTab), findsOneWidget);
    expect(find.text('Log reading'), findsNothing);
    expect(find.text('Books'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Suggestions'), findsOneWidget);
    final select = find.widgetWithText(FilledButton, 'Select passage');
    for (final input in ['John 1,3', 'John 3:16–4:12', 'John 3:37']) {
      await tester.enterText(find.byType(TextField), input);
      await tester.pump();
      expect(tester.widget<FilledButton>(select).onPressed, isNull);
      expect(selected, isNull);
    }
    await tester.enterText(find.byType(TextField), 'jhn 3:16-18');
    await tester.pump();
    await tester.tap(select);
    await tester.pumpAndSettle();
    expect(
      selected,
      ScriptureRangeRef(
        bookId: bible.books.firstWhere((b) => b.title == 'John').id,
        chapter: 3,
        startVerse: 16,
        endVerse: 18,
      ),
    );
    await tester.tap(find.text('Choose passage'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1 jhn 2');
    await tester.pump();
    await tester.tap(select);
    await tester.pumpAndSettle();
    expect(
      selected,
      ScriptureRangeRef(
        bookId: bible.books.firstWhere((b) => b.title == '1 John').id,
        chapter: 2,
        startVerse: 1,
        endVerse: 29,
      ),
    );
    expect(await db.getAllResults(), isEmpty);
  });

  testWidgets('single verse selectors never silently shorten a typed range', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    ScriptureRef? selected;
    await tester.pumpWidget(
      host(
        db,
        Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                selected = await Navigator.of(context).push<ScriptureRef>(
                  MaterialPageRoute(builder: (_) => const VerseSelectionPage()),
                );
              },
              child: const Text('Choose verse'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose verse'));
    await tester.pumpAndSettle();
    expect(find.text('Reference'), findsOneWidget);
    expect(find.text('Log reading'), findsNothing);
    final select = find.widgetWithText(FilledButton, 'Select verse');
    for (final input in ['John 3', 'John 3:16-18', 'John 3:16,18']) {
      await tester.enterText(find.byType(TextField), input);
      await tester.pump();
      expect(tester.widget<FilledButton>(select).onPressed, isNull);
    }
    await tester.enterText(find.byType(TextField), 'jhn3:18');
    await tester.pump();
    await tester.tap(select);
    await tester.pumpAndSettle();
    expect(
      selected,
      ScriptureRef(
        bookId: bible.books.firstWhere((b) => b.title == 'John').id,
        chapterNumber: 3,
        verseNumber: 18,
      ),
    );
    expect(await db.getAllResults(), isEmpty);
  });
}
