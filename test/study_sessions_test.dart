import 'dart:async';

import 'package:bible_parser_flutter/bible_parser_flutter.dart';
import 'package:daily_manna/models/concept_map.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/services/spaced_repetition_service.dart';
import 'package:daily_manna/services/study_notes_service.dart';
import 'package:daily_manna/ui/study/study_note_picker.dart';
import 'package:daily_manna/ui/study/concept_map_editor.dart';
import 'package:daily_manna/ui/study/study_notes_detail_page.dart';
import 'package:daily_manna/ui/study/study_result_detail_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class _BibleService extends BibleService {
  @override
  List<Book> get books => [];

  @override
  Map<String, Book> get booksMap => {};

  @override
  String getRangeRefName(ScriptureRangeRef ref) =>
      '${ref.bookId} ${ref.chapter}:${ref.startVerse}-${ref.endVerse ?? ref.startVerse}';

  @override
  String getPassageRange(
    String bookId,
    int chapter,
    int startVerse, {
    int? endVerse,
  }) => 'Passage text';
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

  test('multiline card labels survive Mermaid saves, including old maps', () {
    final legacy = ConceptMapDocument.fromMermaid('''
flowchart TD
  a[First line
Second line]:::keyPoint
  b[[Another line
And another]]:::note
  a ---> b
''');
    expect(legacy.nodes.map((node) => node.label), [
      'First line\nSecond line',
      'Another line\nAnd another',
    ]);
    expect(legacy.nodes.map((node) => node.type), [
      ConceptMapNodeType.keyPoint,
      ConceptMapNodeType.note,
    ]);
    const label = 'First ] line\r\nLiteral #10; and #93;\nLast line';
    final document = legacy.updateNode(
      legacy.nodes.first.copyWith(label: label),
    );
    final restored = ConceptMapDocument.fromMermaid(document.toMermaid());
    expect(restored.nodes.first.label, label);
    expect(restored.nodes[1].label, 'Another line\nAnd another');
    expect(restored.edges.single.from, 'a');
    expect(restored.edges.single.to, 'b');
  });

  test(
    'clearing notes persists while map-only updates leave notes alone',
    () async {
      final note = await notesService.createNote(
        title: 'Wisdom',
        passage: passage,
      );
      await notesService.updateNotes(note.id, 'Original');
      await notesService.addPassage(note.id, otherPassage);
      expect((await notesService.getNote(note.id))!.notes, 'Original');
      await notesService.updateNotes(note.id, null);
      final cleared = (await notesService.getNote(note.id))!;
      expect(cleared.notes, isNull);
      expect(notesService.passagesFor(cleared), [passage, otherPassage]);
      expect(
        ConceptMapDocument.fromMermaid(cleared.conceptMap!).nodes,
        hasLength(2),
      );
    },
  );

  test('passage visibility is a per-card Mermaid setting', () {
    final document = ConceptMapDocument.fromMermaid('''
flowchart TD
  a[James]:::passage
  b[John]:::passage
  class b showPassage
  click a "passage://Jas/1/9/11"
  click b "passage://John/3/16/"
  a ---> b
''');
    expect(document.nodes.map((node) => node.showPassage), [false, true]);
    expect(document.nodes[1].copyWith(label: 'Changed').showPassage, isTrue);
    expect(document.toMermaid(), contains('class b showPassage'));
    final hidden = document.updateNode(
      document.nodes[1].copyWith(showPassage: false),
    );
    expect(hidden.toMermaid(), isNot(contains('showPassage')));
    expect(
      ConceptMapDocument.fromMermaid(
        hidden.toMermaid(),
      ).nodes.map((node) => node.showPassage),
      [false, false],
    );
    expect(document.nodes[1].passage, otherPassage);
    expect(document.edges.single.to, 'b');
  });

  test('map layout leaves room for expanded cards in each column', () {
    const document = ConceptMapDocument(
      nodes: [
        ConceptMapNode(id: 'a', type: ConceptMapNodeType.passage, label: 'A'),
        ConceptMapNode(id: 'b', type: ConceptMapNodeType.passage, label: 'B'),
        ConceptMapNode(id: 'd', type: ConceptMapNodeType.note, label: 'D'),
        ConceptMapNode(id: 'c', type: ConceptMapNodeType.note, label: 'C'),
      ],
      edges: [
        ConceptMapEdge(from: 'a', to: 'c'),
        ConceptMapEdge(from: 'b', to: 'd'),
      ],
    );
    final positions = conceptMapLayout(
      document,
      nodeSizes: {
        'a': const Size(210, 278),
        'b': const Size(210, 50),
        'd': const Size(210, 50),
      },
    );
    expect(positions['a'], const Offset(80, 80));
    expect(positions['b'], const Offset(80, 382));
    expect(positions['c'], const Offset(340, 174));
    expect(positions['d'], const Offset(340, 382));
    expect(conceptMapLayout(document)['b'], const Offset(80, 240));
    final tallerTarget = conceptMapLayout(
      document,
      nodeSizes: {'c': const Size(210, 278)},
    );
    expect(tallerTarget['a']!.dy + 45, tallerTarget['c']!.dy + 139);
    expect(tallerTarget['c']!.dy, greaterThanOrEqualTo(80));
    expect(
      tallerTarget['d']!.dy,
      greaterThanOrEqualTo(tallerTarget['c']!.dy + 302),
    );
  });

  Widget host(Widget home, {GoRouter? router}) => MultiProvider(
    providers: [
      Provider.value(value: database),
      Provider<StudyNotesService>.value(value: notesService),
      Provider(create: (_) => ResultsService(database)),
      Provider<BibleService>(create: (_) => _BibleService()),
      Provider(create: (_) => SpacedRepetitionService(database)),
    ],
    child: router == null
        ? MaterialApp(home: home)
        : MaterialApp.router(routerConfig: router),
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

  testWidgets('cyclic maps stay compact and all cards fit the canvas', (
    tester,
  ) async {
    const document = ConceptMapDocument(
      nodes: [
        ConceptMapNode(id: 'a', type: ConceptMapNodeType.note, label: 'A'),
        ConceptMapNode(id: 'b', type: ConceptMapNodeType.note, label: 'B'),
        ConceptMapNode(id: 'c', type: ConceptMapNodeType.note, label: 'C'),
      ],
      edges: [
        ConceptMapEdge(from: 'a', to: 'b'),
        ConceptMapEdge(from: 'b', to: 'a'),
        ConceptMapEdge(from: 'a', to: 'c', length: 4),
      ],
    );
    await tester.pumpWidget(
      host(
        Scaffold(
          body: ConceptMapEditor(
            document: document,
            editing: false,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final positions = conceptMapLayout(document);
    expect(positions['a']!.dx, lessThanOrEqualTo(340));
    expect(positions['b']!.dx, lessThanOrEqualTo(340));
    final canvas = tester.widget<SizedBox>(
      find
          .descendant(
            of: find.byType(InteractiveViewer),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    for (final position in positions.values) {
      expect(position.dx + 210, lessThanOrEqualTo(canvas.width!));
      expect(position.dy + 80, lessThanOrEqualTo(canvas.height!));
    }
  });

  testWidgets('linked sessions reopen current notes and can clear their text', (
    tester,
  ) async {
    late StudyNote note;
    late Result result;
    await tester.runAsync(() async {
      note = await notesService.createNote(title: 'Wisdom', passage: passage);
      await notesService.updateNotes(note.id, 'Original');
      await ResultsService(
        database,
      ).addStudyResult(passage, studyNoteId: note.clientId);
      result = (await database.getAllResults()).single;
    });
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => StudyResultDetailPage(result: result),
        ),
        GoRoute(
          path: '/study-notes/:id',
          builder: (_, state) =>
              StudyNotesDetailPage(note: state.extra! as StudyNote),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(host(const SizedBox(), router: router));
    await tester.runAsync(() => notesService.getNote(note.id));
    await tester.pumpAndSettle();
    Future<void> open() async {
      await tester.runAsync(() async {
        await tester.tap(find.text('Open study note'));
        await notesService.getNote(note.id);
      });
      await tester.pumpAndSettle();
    }

    Future<void> save() async {
      await tester.runAsync(() async {
        final saved = Completer<void>();
        var writes = 0;
        notesService.onLocalChange = () async {
          if (++writes == 2) saved.complete();
        };
        await tester.tap(find.byTooltip('Save'));
        await saved.future;
        await notesService.getNote(note.id);
      });
      await tester.pumpAndSettle();
    }

    await open();
    expect(find.text('Original'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Updated');
    await tester.tap(find.text('Concept Map'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jas 1:9-11'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show passage'));
    await tester.pumpAndSettle();
    await save();
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await notesService.getNote(note.id);
    });
    await tester.pumpAndSettle();
    await open();
    expect(find.text('Updated'), findsOneWidget);
    expect(find.text('Original'), findsNothing);
    await tester.tap(find.text('Concept Map'));
    await tester.pumpAndSettle();
    expect(find.text('Passage text'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit'));
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await save();
    await tester.runAsync(() async {
      final saved = (await notesService.getNote(note.id))!;
      expect(saved.notes, isNull);
      expect(
        ConceptMapDocument.fromMermaid(
          saved.conceptMap!,
        ).nodes.single.showPassage,
        isTrue,
      );
    });
    expect(find.text('No notes recorded yet'), findsOneWidget);
  });

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
      expect(
        ConceptMapDocument.fromMermaid(
          (await notesService.getNote(unrelated.id))!.conceptMap!,
        ).nodes.map((node) => node.passage),
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
        ConceptMapDocument.fromMermaid(note.conceptMap!).nodes.single.passage,
        passage,
      );
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
    await tester.tap(find.text('Concept Map'));
    await tester.pumpAndSettle();
    expect(find.text('John 3:16-16'), findsOneWidget);
    expect(find.byTooltip('Show passage'), findsNothing);
    expect(find.byIcon(Icons.visibility), findsNothing);
    expect(find.text('Passage text'), findsNothing);
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton &&
                  widget.tooltip == 'Select a passage card',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('John 3:16-16'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show passage'), findsOneWidget);
    await tester.tap(find.byTooltip('Show passage'));
    await tester.pumpAndSettle();
    expect(find.text('Passage text'), findsOneWidget);
    expect(
      tester
          .widget<ConceptMapEditor>(find.byType(ConceptMapEditor))
          .document
          .nodes
          .map((node) => node.showPassage),
      [false, true],
    );
    await tester.tap(find.text('Jas 1:9-11'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show passage'));
    await tester.pumpAndSettle();
    expect(find.text('Passage text'), findsNWidgets(2));
    await tester.tap(find.text('John 3:16-16'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add box'), findsOneWidget);
    expect(find.byTooltip('Save'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide passage'));
    await tester.pumpAndSettle();
    expect(find.text('Passage text'), findsOneWidget);
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await notesService.addPassage(note.id, otherPassage);
      final updated = (await notesService.getNote(note.id))!;
      expect(notesService.passagesFor(updated), [passage, otherPassage]);
      expect(
        ConceptMapDocument.fromMermaid(updated.conceptMap!).nodes,
        hasLength(2),
      );
      expect(await database.getAllResults(), isEmpty);
    });
    expect(find.text('Add passage'), findsOneWidget);
    expect(find.byTooltip('Save'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Keep learning');
    await tester.runAsync(() async {
      final saved = Completer<void>();
      var writes = 0;
      notesService.onLocalChange = () async {
        if (++writes == 2) saved.complete();
      };
      await tester.tap(find.byTooltip('Save'));
      await saved.future;
      note = (await notesService.getNote(note.id))!;
      expect(note.notes, 'Keep learning');
      expect(
        ConceptMapDocument.fromMermaid(
          note.conceptMap!,
        ).nodes.map((node) => node.showPassage),
        [true, false],
      );
    });
    await tester.pumpAndSettle();
    expect(find.text('Keep learning'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(find.text('Concept Map'), findsOneWidget);
    await tester.pumpWidget(
      host(StudyNotesDetailPage(key: const ValueKey('reopened'), note: note)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concept Map'));
    await tester.pumpAndSettle();
    expect(find.text('Passage text'), findsOneWidget);
    expect(find.byTooltip('Show passage'), findsNothing);
    expect(find.byTooltip('Hide passage'), findsNothing);
    expect(find.byTooltip('Edit'), findsOneWidget);
  });

  testWidgets('adding a passage preserves unsaved map nodes and connections', (
    tester,
  ) async {
    late StudyNote note;
    await tester.runAsync(() async {
      note = await notesService.createNote(title: 'Wisdom', passage: passage);
    });
    await tester.pumpWidget(host(StudyNotesDetailPage(note: note)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit'));
    await tester.tap(find.text('Concept Map'));
    await tester.pumpAndSettle();
    final editor = tester.widget<ConceptMapEditor>(
      find.byType(ConceptMapEditor),
    );
    editor.onChanged(
      editor.document
          .addNode(
            const ConceptMapNode(
              id: 'node3',
              type: ConceptMapNodeType.keyPoint,
              label: 'Unsaved insight\nSecond line',
            ),
          )
          .addEdge(const ConceptMapEdge(from: 'node1', to: 'node3', length: 2)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
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
    await tester.tap(find.text('Concept Map'));
    await tester.pumpAndSettle();
    final updated = tester
        .widget<ConceptMapEditor>(find.byType(ConceptMapEditor))
        .document;
    expect(updated.nodes.map((node) => node.id), ['node1', 'node3', 'node4']);
    expect(updated.nodes[1].label, 'Unsaved insight\nSecond line');
    expect(updated.nodes.last.passage, otherPassage);
    expect(updated.edges.single.from, 'node1');
    expect(updated.edges.single.to, 'node3');
    expect(updated.edges.single.length, 2);
    await tester.runAsync(() async {
      final saved = ConceptMapDocument.fromMermaid(
        (await notesService.getNote(note.id))!.conceptMap!,
      );
      expect(saved.nodes.map((node) => node.id), ['node1', 'node3', 'node4']);
      expect(saved.nodes[1].label, 'Unsaved insight\nSecond line');
      expect(saved.edges.single.to, 'node3');
      expect(await database.getAllResults(), isEmpty);
    });
  });
}
