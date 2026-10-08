import 'package:bible_parser_flutter/bible_parser_flutter.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/services/spaced_repetition_service.dart';
import 'package:daily_manna/services/study_notes_service.dart';
import 'package:daily_manna/ui/study/study_note_picker.dart';
import 'package:daily_manna/ui/study/study_notes_detail_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _BibleService extends BibleService {
  @override
  List<Book> get books => [];

  @override
  Map<String, Book> get booksMap => {};

  @override
  String getRangeRefName(ScriptureRangeRef ref) =>
      '${ref.bookId} ${ref.chapter}:${ref.startVerse}-${ref.endVerse ?? ref.startVerse}';
}

class _StudyNotesService extends StudyNotesService {
  _StudyNotesService(super.database);

  final visibleNotes = <StudyNote>[];

  @override
  Stream<List<StudyNote>> watchNotes() => Stream.value(visibleNotes);
}

void main() {
  late AppDatabase database;
  late _StudyNotesService notesService;
  const passage = ScriptureRangeRef(
    bookId: 'Jas',
    chapter: 1,
    startVerse: 9,
    endVerse: 11,
  );
  const otherPassage = ScriptureRangeRef(
    bookId: 'John',
    chapter: 3,
    startVerse: 16,
  );

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    notesService = _StudyNotesService(database);
  });

  tearDown(() => database.close());

  Widget host(Widget home) => MultiProvider(
    providers: [
      Provider.value(value: database),
      Provider<StudyNotesService>.value(value: notesService),
      Provider(create: (_) => ResultsService(database)),
      Provider<BibleService>(create: (_) => _BibleService()),
      Provider(create: (_) => SpacedRepetitionService(database)),
    ],
    child: MaterialApp(home: home),
  );

  Future<void> openPicker(WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<StudyNote>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const StudyNotePicker(passage: passage),
              ),
              child: const Text('Study'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Study'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('records a session without creating a note', (tester) async {
    await tester.runAsync(() => database.getAllResults());
    await openPicker(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Record without a note'));
      await database.watchAllResults().firstWhere(
        (results) => results.isNotEmpty,
      );
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final session = (await database.getAllResults()).single;
      expect(session.studyNoteId, isNull);
      expect(session.notes, isNull);
      expect(session.bookId, 'Jas');
      expect(session.endVerse, 11);
      expect(await database.getStudyNotes(), isEmpty);
    });
    expect(find.text('Study session recorded'), findsOneWidget);
  });

  testWidgets('lists unrelated notes and links the chosen existing note', (
    tester,
  ) async {
    late StudyNote unrelated;
    await tester.runAsync(() async {
      final related = await notesService.createNote(
        title: 'Related',
        passage: passage,
      );
      unrelated = await notesService.createNote(
        title: 'Existing topic',
        passage: otherPassage,
      );
      notesService.visibleNotes.addAll([related, unrelated]);
    });
    await openPicker(tester);
    expect(find.text('Related notes'), findsOneWidget);
    expect(find.text('Other notes'), findsOneWidget);
    expect(find.text('Related'), findsOneWidget);
    expect(find.text('Existing topic'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Existing topic'));
      await database.watchAllResults().firstWhere(
        (results) => results.isNotEmpty,
      );
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final session = (await database.getAllResults()).single;
      expect(session.studyNoteId, unrelated.clientId);
      expect(session.notes, isNull);
      expect(await database.getStudyNotes(), hasLength(2));
      expect(
        notesService.passagesFor((await notesService.getNote(unrelated.id))!),
        [otherPassage, passage],
      );
    });
  });

  testWidgets('new note remains optional and is linked when created', (
    tester,
  ) async {
    await tester.runAsync(() => database.getAllResults());
    await openPicker(tester);
    await tester.runAsync(() => tester.tap(find.text('Create new study note')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Wisdom');
    await tester.runAsync(() async {
      await tester.tap(find.text('Create'));
      await database.watchAllResults().firstWhere(
        (results) => results.isNotEmpty,
      );
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final note = (await database.getStudyNotes()).single;
      expect(note.title, 'Wisdom');
      expect(
        (await database.getAllResults()).single.studyNoteId,
        note.clientId,
      );
    });
  });

  testWidgets('add passage persists without a session and keeps the edit FAB', (
    tester,
  ) async {
    late StudyNote note;
    await tester.runAsync(() async {
      note = await notesService.createNote(title: 'Wisdom', passage: passage);
    });
    await tester.pumpWidget(host(StudyNotesDetailPage(note: note)));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget);
    // Exercise the passage-selector return contract independently of its
    // range-selection controls, which have their own regression tests.
    await tester.runAsync(() async {
      await tester.tap(find.text('Add passage'));
      Navigator.of(
        tester.element(find.byType(StudyNotesDetailPage)),
      ).pop(otherPassage);
      await database.watchStudyNotes().firstWhere(
        (notes) =>
            notesService.passagesFor(notes.single).contains(otherPassage),
      );
    });
    await tester.pumpAndSettle();
    expect(find.text('John 3:16-16'), findsOneWidget);
    await tester.runAsync(() async {
      await notesService.addPassage(note.id, otherPassage);
      expect(notesService.passagesFor((await notesService.getNote(note.id))!), [
        passage,
        otherPassage,
      ]);
      expect(await database.getAllResults(), isEmpty);
    });
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Add passage'), findsOneWidget);
    expect(find.byTooltip('Save'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Keep learning');
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Save'));
      await database.watchStudyNotes().firstWhere(
        (notes) =>
            notes.single.notes == 'Keep learning' &&
            notes.single.conceptMap != null,
      );
    });
    await tester.pumpAndSettle();
    expect(find.text('Keep learning'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(find.text('Concept Map'), findsOneWidget);
  });
}
