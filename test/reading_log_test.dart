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
import 'package:daily_manna/ui/memorization/interact_result.dart';
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
      '${booksMap[ref.bookId]!.title} ${ref.chapter}:${ref.startVerse}'
      '${ref.endVerse != null && ref.endVerse != ref.startVerse ? '-${ref.endVerse}' : ''}';
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
      expect(labels('D 8'), ['Deuteronomy 8']);
      expect(labels('d.8'), ['Deuteronomy 8']);
      expect(labels('Dan 8'), ['Daniel 8']);
      expect(labels('Jo 1'), ['Joshua 1']);
      expect(labels('John 1'), ['John 1']);
    },
  );

  test('ordered letters match abbreviations without per-book aliases', () {
    List<String> matchingBooks(String input) => parser
        .parse(input, includeAlternatives: true)
        .map((passage) => bible.booksMap[passage.bookId]!.title)
        .toList();

    expect(matchingBooks('dtrn 8'), ['Deuteronomy']);
    expect(matchingBooks('hbk 2'), ['Habakkuk']);
    expect(matchingBooks('zph 1'), ['Zephaniah']);
    expect(matchingBooks('mrk 2'), ['Mark']);
    expect(matchingBooks('jm 1'), ['James', 'Jeremiah']);
    expect(matchingBooks('D 8'), ['Deuteronomy', 'Daniel']);
    expect(matchingBooks('Dan 8'), ['Daniel']);
    expect(matchingBooks('jhn 1'), ['John']);
    expect(matchingBooks('2 jhn 1'), ['2 John']);
    expect(matchingBooks('song of songs 1'), ['Song of Solomon']);
    expect(() => matchingBooks('nhj 1'), throwsFormatException);
  });

  test('cross-chapter and mixed ranges retain both endpoints', () {
    expect(labels('John 3:16–4:12'), ['John 3:16–4:12']);
    expect(labels('John 3–4:12'), ['John 3:1–4:12']);
    expect(labels('John 1:5–2:5'), ['John 1:5–2:5']);
  });

  test(
    'alternative matches validate each book and retain reference context',
    () {
      List<String> matches(String input) => parser
          .parse(input, includeAlternatives: true)
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
      expect(matches('D 8'), ['Deuteronomy 8', 'Daniel 8']);
      expect(matches('D 8,9'), [
        'Deuteronomy 8',
        'Daniel 8',
        'Deuteronomy 9',
        'Daniel 9',
      ]);
      expect(matches('D 8:25'), ['Daniel 8:25']);
      expect(matches('D 13'), ['Deuteronomy 13']);
      expect(matches('Dan 8'), ['Daniel 8']);
      expect(matches('D 8; John 1,3'), [
        'Deuteronomy 8',
        'Daniel 8',
        'John 1',
        'John 3',
      ]);
      expect(() => matches('D 8:99'), throwsFormatException);
      expect(() => matches('D 8; John 99'), throwsFormatException);
    },
  );

  test('partial input and invalid passages reject the entire submission', () {
    for (final input in [
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
  });

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

  testWidgets(
    'reference titles select only when tapped and clear invalid matches',
    (tester) async {
      ScriptureRangeRef? selected;
      await tester.pumpWidget(
        Provider<BibleService>.value(
          value: bible,
          child: MaterialApp(
            home: Scaffold(
              body: ReferenceTab(onSelected: (ref) => selected = ref),
            ),
          ),
        ),
      );
      expect(find.text('Log reading'), findsNothing);
      await tester.enterText(find.byType(TextField), 'John 1,3');
      await tester.pump();
      expect(find.text('Preview'), findsNothing);
      expect(find.byType(Divider), findsOneWidget);
      expect(find.text('John 1'), findsOneWidget);
      expect(find.text('John 3'), findsOneWidget);
      expect(selected, isNull);
      await tester.enterText(find.byType(TextField), 'jhn3:16-18');
      await tester.pump();
      expect(find.text('John 3:16–18'), findsOneWidget);
      expect(selected, isNull);
      await tester.enterText(find.byType(TextField), 'John 1,999');
      await tester.pump();
      expect(selected, isNull);
      expect(find.byType(ListTile), findsNothing);
      await tester.enterText(find.byType(TextField), '1 jhn 2');
      await tester.pump();
      await tester.tap(find.text('1 John 2'));
      expect(
        (selected!.chapter, selected!.startVerse, selected!.endVerse),
        (2, 1, 29),
      );
      await tester.enterText(find.byType(TextField), 'D 8');
      await tester.pump();
      expect(find.text('Deuteronomy 8'), findsOneWidget);
      expect(find.text('Daniel 8'), findsOneWidget);
      await tester.tap(find.text('Deuteronomy 8'));
      expect(
        selected,
        ScriptureRangeRef(
          bookId: bible.books
              .firstWhere((book) => book.title == 'Deuteronomy')
              .id,
          chapter: 8,
          startVerse: 1,
          endVerse: 20,
        ),
      );
      await tester.tap(find.text('Daniel 8'));
      expect(
        selected,
        ScriptureRangeRef(
          bookId: bible.books.firstWhere((book) => book.title == 'Daniel').id,
          chapter: 8,
          startVerse: 1,
          endVerse: 27,
        ),
      );
    },
  );

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

  testWidgets('Interact selects passage titles immediately without logging', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(() => db.getAllResults());
    await tester.pumpWidget(host(db, const HomePage()));
    await tester.pumpAndSettle();
    expect(find.text('Log reading'), findsNothing);
    await tester.tap(find.text('Interact'));
    await tester.pumpAndSettle();
    expect(find.text('Search'), findsOneWidget);
    expect(find.byType(ReferenceTab), findsOneWidget);
    expect(find.byType(ActionChip), findsNothing);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    await tester.enterText(find.byType(TextField), '1 jhn 2');
    await tester.pump();
    expect(find.text('1 John 2'), findsOneWidget);
    expect(find.text('Log reading'), findsNothing);
    expect(find.text('Memorize'), findsNothing);
    expect(find.text('Select passage'), findsNothing);
    await tester.tap(find.text('1 John 2'));
    await tester.pumpAndSettle();
    expect(find.byType(ReferenceTab), findsNothing);
    expect(find.text('Memorize'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
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
    expect(find.byType(ReferenceTab), findsNothing);
    expect(find.text('Memorize'), findsOneWidget);
    expect(find.text('Recite'), findsOneWidget);
    expect(find.text('Study'), findsOneWidget);
    await tester.runAsync(() async {
      expect(await db.getAllResults(), isEmpty);
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('shared passage selectors return typed ranges without logging', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
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
    expect(find.text('Search'), findsOneWidget);
    expect(find.byType(ReferenceTab), findsOneWidget);
    expect(find.text('Log reading'), findsNothing);
    expect(find.text('Books'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Suggestions'), findsOneWidget);
    expect(find.text('Select passage'), findsNothing);
    for (final input in ['John 3:16–4:12', 'John 3:37']) {
      await tester.enterText(find.byType(TextField), input);
      await tester.pump();
      expect(find.byType(ListTile), findsNothing);
      expect(selected, isNull);
    }
    await tester.enterText(find.byType(TextField), 'jhn 3:16-18');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    final match = find.text('John 3:16–18');
    expect(tester.getBottomRight(match).dy, lessThanOrEqualTo(544));
    await tester.tap(match);
    await tester.pumpAndSettle();
    tester.view.resetViewInsets();
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
    await tester.tap(find.text('1 John 2'));
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

  testWidgets(
    'each tab returns its tapped passage immediately without logging',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final john = bible.books.firstWhere((b) => b.title == 'John').id;
      await tester.runAsync(() async {
        for (final verse in [18, 21]) {
          await ResultsService(db).addMemorizationResult(
            MemorizationResult(
              ref: ScriptureRef(
                bookId: john,
                chapterNumber: 3,
                verseNumber: verse,
              ),
              attempts: 1,
              score: 1,
            ),
          );
        }
      });
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
      for (final tab in ['Search', 'Books', 'Review', 'Suggestions']) {
        selected = null;
        await tester.tap(find.text('Choose passage'));
        await tester.pumpAndSettle();
        expect(find.text('Select passage'), findsNothing);
        if (tab != 'Search') {
          await tester.tap(find.text(tab));
          await tester.pumpAndSettle();
        }
        ScriptureRangeRef expected;
        if (tab == 'Search') {
          await tester.enterText(find.byType(TextField), 'John 1,3');
          await tester.pump();
          expect(selected, isNull);
          await tester.tap(find.text('John 3'));
          expected = ScriptureRangeRef(
            bookId: john,
            chapter: 3,
            startVerse: 1,
            endVerse: 36,
          );
        } else if (tab == 'Books') {
          await tester.tap(find.text('Deuteronomy'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('1').first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('3').first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('7').first);
          expected = ScriptureRangeRef(
            bookId: bible.books.firstWhere((b) => b.title == 'Deuteronomy').id,
            chapter: 1,
            startVerse: 3,
            endVerse: 7,
          );
        } else {
          await tester.runAsync(() => db.getAllResults());
          await tester.pumpAndSettle();
          final verse = tab == 'Review' ? 18 : 21;
          await tester.tap(find.text('John 3:$verse'));
          expected = ScriptureRangeRef(
            bookId: john,
            chapter: 3,
            startVerse: verse,
          );
        }
        await tester.pumpAndSettle();
        expect(selected, expected, reason: tab);
        expect(find.byType(VerseSelectionPage), findsNothing);
        expect(find.text('Log reading'), findsNothing);
      }
      await tester.runAsync(() async {
        expect(await db.getAllResults(), hasLength(2));
      });
    },
  );

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
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Log reading'), findsNothing);
    expect(find.text('Select verse'), findsNothing);
    for (final input in ['John 3', 'John 3:16-18']) {
      await tester.enterText(find.byType(TextField), input);
      await tester.pump();
      expect(find.byType(ListTile), findsNothing);
    }
    await tester.enterText(find.byType(TextField), 'jhn3:18');
    await tester.pump();
    await tester.tap(find.text('John 3:18'));
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
