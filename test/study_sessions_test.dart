import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

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
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Stream<List<StudyNote>> watchNotes({bool archived = false}) => Stream.value(
    visibleNotes.where((note) => note.archived == archived).toList(),
  );
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

  Future<void> selectCard(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  test(
    'note edits automatically record one note-anchored session per day',
    () async {
      final service = StudyNotesService(database);
      final note = await service.createNote(title: 'Stewardship');
      expect(service.passagesFor(note), isEmpty);
      await service.getNote(note.id);
      await service.updateNotes(note.id, null);
      await service.updateConceptMap(note.id, note.conceptMap!);
      await service.setArchived(note.id, true);
      await service.setArchived(note.id, false);
      expect(await database.getAllResults(), isEmpty);

      await service.updateNotes(note.id, 'Everything belongs to God');
      final first = (await database.getAllResults()).single;
      expect(first.studyNoteId, note.clientId);
      expect(first.bookId, isNull);
      expect(first.startChapter, isNull);
      expect(first.startVerse, isNull);
      await service.updateNotes(note.id, 'Use resources faithfully');
      await service.updateConceptMap(note.id, 'flowchart TD\n a[Stewardship]');
      await service.addPassage(note.id, passage);
      expect((await database.getAllResults()).single.clientId, first.clientId);
      expect(await database.getUniqueVersesInteracted(), isEmpty);
      expect(
        await SpacedRepetitionService(database).getVersesByReviewDate(),
        isEmpty,
      );
      final sections = await ResultsService(
        database,
      ).getTodaySections(_BibleService());
      expect(sections.single.items.single.reference, 'Stewardship');

      final other = await service.createNote(title: 'Wisdom');
      await service.updateNotes(other.id, 'Ask God for wisdom');
      expect(await database.getAllResults(), hasLength(2));
      final results = ResultsService(database);
      await results.addStudyResult(passage);
      await results.addStudyResult(passage);
      final sessions = await database.getAllResults();
      expect(sessions, hasLength(4));
      expect(
        sessions.where((r) => r.studyNoteId == null).map((r) => r.bookId),
        ['Jas', 'Jas'],
      );
      expect(
        (await database.pendingChanges()).where(
          (c) => c.entityType == 'result' || c.entityType == 'study_session',
        ),
        hasLength(4),
      );
    },
  );

  test(
    'note sessions separate calendar days rather than rolling 24 hours',
    () async {
      final note = await notesService.createNote(title: 'Wisdom');
      await database.recordStudyNoteSession(
        note.clientId,
        timestamp: DateTime(2026, 3, 8, 23, 59),
      );
      await database.recordStudyNoteSession(
        note.clientId,
        timestamp: DateTime(2026, 3, 9),
      );
      await database.recordStudyNoteSession(
        note.clientId,
        timestamp: DateTime(2026, 3, 9, 23, 59),
      );
      final sessions = await database.getAllResults();
      expect(sessions, hasLength(2));
      expect(sessions.map((r) => r.timestamp.toLocal().day), [9, 8]);
      expect(sessions.map((r) => r.clientId).toSet(), hasLength(2));
    },
  );

  test(
    'archiving hides notes without breaking session links or note content',
    () async {
      final service = StudyNotesService(database);
      final note = await service.createNote(title: 'Wisdom', passage: passage);
      await service.updateNotes(note.id, 'Keep this text');
      await ResultsService(
        database,
      ).addStudyResult(passage, studyNoteId: note.clientId);
      await service.setArchived(note.id, true);
      expect(await service.watchNotes().first, isEmpty);
      expect(
        (await service.watchNotes(archived: true).first).single.clientId,
        note.clientId,
      );
      final linked = await service.getNoteByClientId(
        (await database.getAllResults()).single.studyNoteId!,
      );
      expect(linked!.archived, isTrue);
      expect(linked.notes, 'Keep this text');
      expect(linked.conceptMap, note.conceptMap);
      expect(service.passagesFor(linked), [passage]);
      await service.setArchived(note.id, false);
      expect((await service.watchNotes().first).single.clientId, note.clientId);
      expect(await service.watchNotes(archived: true).first, isEmpty);
    },
  );

  testWidgets(
    'note menu archives, undoes and restores only outside edit mode',
    (tester) async {
      Future<void> choose(String label, bool archived) async {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await database
              .watchStudyNotes()
              .firstWhere((notes) => notes.single.archived == archived)
              .timeout(const Duration(seconds: 5));
        });
        await tester.pumpAndSettle();
      }

      late StudyNote note;
      await tester.runAsync(() async {
        note = await notesService.createNote(title: 'Wisdom', passage: passage);
      });
      await tester.pumpWidget(host(StudyNotesDetailPage(note: note)));
      await tester.tap(find.byTooltip('Note actions'));
      await tester.pumpAndSettle();
      await choose('Archive note', true);
      expect(find.text('Archived'), findsOneWidget);
      await choose('Undo', false);
      expect(find.text('Archived'), findsNothing);
      await tester.tap(find.byTooltip('Note actions'));
      await tester.pumpAndSettle();
      await choose('Archive note', true);
      await tester.tap(find.byTooltip('Note actions'));
      await tester.pumpAndSettle();
      await choose('Restore note', false);
      expect(find.text('Archived'), findsNothing);
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Note actions'), findsNothing);
    },
  );

  testWidgets('Markdown toolbar edits selections and keeps PDF in app bar', (
    tester,
  ) async {
    late StudyNote note;
    await tester.runAsync(() async {
      note = await notesService.createNote(title: 'Outline');
    });
    await tester.pumpWidget(host(StudyNotesDetailPage(note: note)));
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip('Generate PDF'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    final editor = find.byType(TextField);
    expect(tester.widget<TextField>(editor).style?.fontFamily, 'monospace');
    final controller = tester.widget<TextField>(editor).controller!;
    await tester.enterText(editor, '##### Heading');
    await tester.tap(find.byTooltip('Increase heading'));
    expect(controller.text, '###### Heading');
    await tester.tap(find.byTooltip('Increase heading'));
    expect(controller.text, '###### Heading');
    await tester.enterText(editor, '      + Deep point');
    await tester.tap(find.byTooltip('Increase bullet indent'));
    expect(controller.text, '        - Deep point');
    await tester.tap(find.byTooltip('Decrease bullet indent'));
    expect(controller.text, '      - Deep point');
    await tester.enterText(editor, 'First\nSecond\nThird');
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 13);
    await tester.tap(find.byTooltip('Blockquote'));
    expect(controller.text, '> First\n> Second\nThird');
    controller.selection = const TextSelection(
      baseOffset: 17,
      extentOffset: 22,
    );
    await tester.tap(find.byTooltip('Bold (blue)'));
    expect(controller.text, '> First\n> Second\n**Third**');
    expect(find.byTooltip('Read passage (red)'), findsNothing);
    expect(find.byTooltip('Preview Markdown'), findsNothing);
    await tester.tap(find.byTooltip('Generate PDF'));
    await tester.pumpAndSettle();
    expect(find.text('Half-letter · 5.5 × 8.5 in · 8 pt'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(controller.text, '> First\n> Second\n**Third**');
    await tester.tap(find.byTooltip('Save'));
    await tester.runAsync(() async {
      await database.watchStudyNotes().firstWhere(
        (notes) => notes.single.notes == '> First\n> Second\n**Third**',
      );
    });
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('Third', findRichText: true), findsOneWidget);
  });

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

  test(
    'map passages appear in legacy notes, search, and subsequent saves',
    () async {
      const isaiah = ScriptureRangeRef(
        bookId: 'Isa',
        chapter: 40,
        startVerse: 6,
        endVerse: 8,
      );
      final note = await notesService.createNote(
        title: 'Glory',
        passage: passage,
      );
      // Simulate an older/synced note whose map was saved without its passage list.
      const map = '''
flowchart TD
  james[James 1:10]:::passage
  click james "passage://Jas/1/10/"
  isaiah[Isaiah 40:6-8]:::passage
  click isaiah "passage://Isa/40/6/8"
  duplicate[Isaiah again]:::passage
  click duplicate "passage://Isa/40/6/8"
''';
      await database.updateStudyNote(note.id, conceptMap: map);
      final legacy = (await notesService.getNote(note.id))!;
      expect(notesService.passagesFor(legacy), [passage, isaiah]);
      expect(
        (await notesService.findByPassage(
          isaiah.copyWith(startVerse: 7, endVerse: 7),
        )).single.id,
        note.id,
      );
      expect(
        await notesService.findByPassage(
          isaiah.copyWith(startVerse: 9, endVerse: 9),
        ),
        isEmpty,
      );

      // Overlap is not containment: the newly added range also includes verse 9.
      final overlapping = isaiah.copyWith(startVerse: 8, endVerse: 10);
      await notesService.updateConceptMap(
        note.id,
        ConceptMapDocument.fromMermaid(map).addPassage(overlapping).toMermaid(),
      );
      final saved = (await notesService.getNote(note.id))!;
      expect(
        notesService.passagesFor(saved.copyWith(conceptMap: const Value(null))),
        [passage, isaiah, overlapping],
      );
      expect(
        (await notesService.findByPassage(
          isaiah.copyWith(startVerse: 9, endVerse: 9),
        )).single.id,
        note.id,
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

  testWidgets('toolbar converts key points to notes without losing links', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final document = ConceptMapDocument.fromMermaid('''
flowchart TD
  key[The Lowly Should Glory in Their High Position]:::keyPoint
  verse[James 1:9]:::passage
  lowly[The Lowly]:::keyPoint
  key ---> verse
  verse ---> lowly
''');
    final original = document.toMermaid();
    late StudyNote note;
    await tester.runAsync(() async {
      note = await notesService.createNote(title: 'Glory in the Lord');
      await notesService.updateConceptMap(note.id, original);
      note = (await notesService.getNote(note.id))!;
    });
    await tester.pumpWidget(host(StudyNotesDetailPage(note: note)));
    await tester.tap(find.text('Concept Map'));
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('The Lowly'));
    await tester.pumpAndSettle();
    expect(find.text('Change to note'), findsOneWidget);
    final drag = await tester.startGesture(
      tester.getCenter(find.text('The Lowly')),
    );
    await drag.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 700));
    await drag.up();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    await selectCard(tester, 'The Lowly');
    await tester.ensureVisible(find.text('Change to note'));
    await tester.tap(find.text('Change to note'));
    await tester.pumpAndSettle();
    ConceptMapDocument currentDocument() =>
        tester.widget<ConceptMapEditor>(find.byType(ConceptMapEditor)).document;
    final restored = ConceptMapDocument.fromMermaid(
      currentDocument().toMermaid(),
    );
    expect(restored.nodes.last.type, ConceptMapNodeType.note);
    expect(
      currentDocument().toMermaid(),
      original.replaceFirst(
        'lowly[The Lowly]:::keyPoint',
        'lowly[The Lowly]:::note',
      ),
    );
    expect(
      tester.getTopLeft(find.text('The Lowly')).dx,
      greaterThan(tester.getTopLeft(find.text('James 1:9')).dx),
    );
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Save'));
      note = (await notesService.getNote(note.id))!;
      expect(note.conceptMap, currentDocument().toMermaid());
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await selectCard(tester, 'The Lowly');
    await tester.ensureVisible(find.text('Change to key point'));
    await tester.tap(find.text('Change to key point'));
    await tester.pumpAndSettle();
    expect(currentDocument().toMermaid(), original);
    await tester.tap(find.text('James 1:9'));
    await tester.pumpAndSettle();
    await selectCard(tester, 'James 1:9');
    expect(find.text('Change to note'), findsNothing);
    expect(find.text('Change to key point'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);
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
    expect(positions['b']!.dy - (positions['a']!.dy + 278), 80);
    expect(positions['c']!.dy + 45, positions['a']!.dy + 139);
    expect(positions['d']!.dy + 25, positions['b']!.dy + 25);
    final defaultPositions = conceptMapLayout(document);
    expect(defaultPositions['b']!.dy - (defaultPositions['a']!.dy + 90), 80);
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
    expect(tallerTarget['b']!.dy + 45, tallerTarget['d']!.dy + 45);
  });

  for (final measured in [false, true]) {
    test(
      'exported branches stay centered and separate (measured: $measured)',
      () {
        final document = ConceptMapDocument.fromMermaid(
          File('test/fixtures/glory_in_the_lord.mmd').readAsStringSync(),
        );
        final sizes = measured
            ? {
                for (final node in document.nodes)
                  node.id: Size(300, switch (node.id) {
                    'node3' => 100,
                    'node5' => 120,
                    'node7' => 184,
                    'node15' => 52,
                    'node16' => 68,
                    _ => 44,
                  }),
              }
            : <String, Size>{};
        final positions = conceptMapLayout(document, nodeSizes: sizes);
        Rect card(String id) =>
            positions[id]! & (sizes[id] ?? const Size(300, 90));

        // An asymmetric pair catches using card tops rather than branch bounds.
        expect(
          card('node7').center.dy,
          closeTo((card('node15').top + card('node16').bottom) / 2, .001),
        );
        expect(card('node15').center.dy, lessThan(card('node7').center.dy));
        expect(card('node16').center.dy, greaterThan(card('node7').center.dy));
        final exampleGap = card('node21').top - card('node20').bottom;
        final groupGap = card('node20').top - card('node7').bottom;
        expect(exampleGap, closeTo(24, .001));
        expect(groupGap, greaterThanOrEqualTo(80));
        expect(groupGap, greaterThan(exampleGap));
        expect(
          card('node19').center.dy,
          closeTo((card('node20').top + card('node24').bottom) / 2, .001),
        );
        // Isaiah is shared by two branches; it must not drag either note down.
        expect(
          card('node5').center.dy,
          closeTo((card('node13').top + card('node17').bottom) / 2, .001),
        );
        for (final a in document.nodes) {
          for (final b in document.nodes) {
            if (a.id != b.id) expect(card(a.id).overlaps(card(b.id)), isFalse);
          }
        }
      },
    );
  }

  test('key points reserve space for their expanded scripture branches', () {
    final document = ConceptMapDocument(
      nodes: [
        for (final id in ['p', 'q', 'r', 's', 't', 'u'])
          ConceptMapNode(id: id, type: ConceptMapNodeType.passage, label: id),
        for (final id in ['a', 'b', 'c'])
          ConceptMapNode(id: id, type: ConceptMapNodeType.keyPoint, label: id),
      ],
      edges: const [
        ConceptMapEdge(from: 'a', to: 'p'),
        ConceptMapEdge(from: 'a', to: 'q'),
        ConceptMapEdge(from: 'a', to: 'r'),
        ConceptMapEdge(from: 'b', to: 's'),
        ConceptMapEdge(from: 'c', to: 't'),
        ConceptMapEdge(from: 't', to: 'u'),
      ],
    );
    const sizes = {
      'a': Size(300, 50),
      'b': Size(300, 50),
      'c': Size(300, 50),
      'p': Size(300, 120),
      'q': Size(300, 340),
      'r': Size(300, 80),
      's': Size(300, 180),
      't': Size(300, 100),
      'u': Size(300, 400),
    };
    final positions = conceptMapLayout(document, nodeSizes: sizes);
    for (var mask = 0; mask < 1 << document.edges.length; mask++) {
      final edges = [
        for (var i = 0; i < document.edges.length; i++)
          ConceptMapEdge(
            from: mask & (1 << i) == 0
                ? document.edges[i].from
                : document.edges[i].to,
            to: mask & (1 << i) == 0
                ? document.edges[i].to
                : document.edges[i].from,
            length: document.edges[i].length,
          ),
      ];
      for (final ordering in [edges, edges.reversed.toList()]) {
        expect(
          conceptMapLayout(
            ConceptMapDocument(nodes: document.nodes, edges: ordering),
            nodeSizes: sizes,
          ),
          positions,
          reason:
              'Tap directions $mask and connection order must not affect layout',
        );
      }
    }
    expect(
      positions['a']!.dy + 25,
      (positions['p']!.dy + positions['r']!.dy + 80) / 2,
    );
    expect(positions['b']!.dy + 25, positions['s']!.dy + 90);
    expect(positions['c']!.dy + 25, positions['u']!.dy + 200);
    expect(positions['s']!.dy, greaterThanOrEqualTo(positions['r']!.dy + 104));
    expect(positions['u']!.dy, greaterThanOrEqualTo(positions['s']!.dy + 204));
    final first = [
      for (final edge in document.edges.where((edge) => edge.from == 'a'))
        conceptMapConnector(edge, positions, sizes),
    ];
    final second = conceptMapConnector(document.edges[3], positions, sizes);
    for (final route in [...first, second]) {
      expect(route, isNotEmpty);
    }
    for (final route in first) {
      for (var i = 1; i < route.length; i++) {
        for (var j = 1; j < second.length; j++) {
          final a = Rect.fromPoints(route[i - 1], route[i]).inflate(1.5);
          final b = Rect.fromPoints(second[j - 1], second[j]).inflate(1.5);
          expect(a.overlaps(b), isFalse);
        }
      }
    }
  });

  test(
    'undirected layout uses short paths and connected anchors through cycles',
    () {
      const document = ConceptMapDocument(
        nodes: [
          ConceptMapNode(id: 'p', type: ConceptMapNodeType.passage, label: 'P'),
          ConceptMapNode(id: 'q', type: ConceptMapNodeType.passage, label: 'Q'),
          ConceptMapNode(
            id: 'leaf',
            type: ConceptMapNodeType.note,
            label: 'Leaf',
          ),
          ConceptMapNode(id: 'x', type: ConceptMapNodeType.note, label: 'X'),
          ConceptMapNode(id: 'y', type: ConceptMapNodeType.note, label: 'Y'),
          ConceptMapNode(
            id: 'hub',
            type: ConceptMapNodeType.note,
            label: 'Hub',
          ),
          ConceptMapNode(
            id: 'key',
            type: ConceptMapNodeType.keyPoint,
            label: 'Key',
          ),
        ],
        edges: [
          ConceptMapEdge(from: 'p', to: 'key'),
          ConceptMapEdge(from: 'q', to: 'p'),
          ConceptMapEdge(from: 'key', to: 'q', length: 4),
          ConceptMapEdge(from: 'leaf', to: 'hub'),
          ConceptMapEdge(from: 'x', to: 'hub'),
          ConceptMapEdge(from: 'hub', to: 'y'),
          ConceptMapEdge(from: 'y', to: 'x'),
        ],
      );
      final positions = conceptMapLayout(document);
      expect(positions['key']!.dx, 80);
      expect(positions['p']!.dx, 430);
      expect(positions['q']!.dx, 780);
      expect(positions['hub']!.dx, 80);
      for (final id in ['leaf', 'x', 'y']) {
        expect(positions[id]!.dx, 430);
      }
      expect(
        conceptMapLayout(
          ConceptMapDocument(
            nodes: document.nodes,
            edges: [
              for (final edge in document.edges.reversed)
                ConceptMapEdge(
                  from: edge.to,
                  to: edge.from,
                  length: edge.length,
                ),
            ],
          ),
        ),
        positions,
      );
    },
  );

  test('connectors route around intervening cards in either direction', () {
    for (final positions in [
      {
        'a': const Offset(80, 80),
        'c': const Offset(430, 80),
        'b': const Offset(780, 80),
      },
      {
        'a': const Offset(80, 80),
        'c': const Offset(80, 220),
        'b': const Offset(80, 600),
      },
      {
        'a': const Offset(80, 80),
        'c': const Offset(430, 160),
        'b': const Offset(430, 600),
      },
    ]) {
      const sizes = {
        'a': Size(300, 90),
        'b': Size(300, 110),
        'c': Size(300, 300),
      };
      final obstacle = positions['c']! & sizes['c']!;
      final forward = conceptMapConnector(
        const ConceptMapEdge(from: 'a', to: 'b'),
        positions,
        sizes,
      );
      expect(
        conceptMapConnector(
          const ConceptMapEdge(from: 'b', to: 'a'),
          positions,
          sizes,
        ),
        forward.reversed.toList(),
      );
      for (final edge in [
        const ConceptMapEdge(from: 'a', to: 'b'),
        const ConceptMapEdge(from: 'b', to: 'a'),
      ]) {
        final route = conceptMapConnector(edge, positions, sizes);
        expect(route, isNotEmpty);
        for (var i = 1; i < route.length; i++) {
          expect(
            route[i].dx == route[i - 1].dx || route[i].dy == route[i - 1].dy,
            isTrue,
          );
          // Include the visible stroke, not just its centerline.
          expect(
            Rect.fromPoints(
              route[i - 1],
              route[i],
            ).inflate(1.5).overlaps(obstacle),
            isFalse,
          );
        }
      }
    }
    final straight = conceptMapConnector(
      const ConceptMapEdge(from: 'a', to: 'b'),
      {'a': const Offset(80, 80), 'b': const Offset(430, 80)},
      const {'a': Size(300, 90), 'b': Size(300, 90)},
    );
    expect(straight.map((point) => point.dy).toSet(), {125});
  });

  test(
    'shared scripture keeps neighboring passage branches visually separate',
    () {
      final document = ConceptMapDocument.fromMermaid('''
flowchart TD
  key10[Glory in humiliation]:::keyPoint
  james10[James 1:10]:::passage
  key11[Unaligned pursuits]:::keyPoint
  james11[James 1:11]:::passage
  isaiah[Isaiah 40:6-8]:::passage
  rich[The Rich]:::note
  humiliation[Humiliation]:::note
  end[Miserable End]:::note
  pursuits[Unaligned Pursuits]:::note
  key10 ---> james10
  key11 ---> james11
  james10 ---> isaiah
  james11 ---> isaiah
  rich ---> james10
  humiliation ---> james10
  end ---> james11
  james11 ---> pursuits
''');
      final sizes = {
        for (final node in document.nodes) node.id: const Size(300, 50),
        'james10': const Size(300, 120),
        'james11': const Size(300, 180),
      };
      final positions = conceptMapLayout(document, nodeSizes: sizes);
      // The shared passage belongs between the two sets of exclusive notes,
      // even though it was created before any of those notes.
      for (final (above, below) in [
        ('rich', 'humiliation'),
        ('humiliation', 'isaiah'),
        ('isaiah', 'end'),
        ('end', 'pursuits'),
      ]) {
        expect(
          positions[above]!.dy + sizes[above]!.height,
          lessThan(positions[below]!.dy),
        );
      }
      final upper = [
        for (final id in ['rich', 'humiliation', 'isaiah'])
          conceptMapConnector(
            ConceptMapEdge(from: 'james10', to: id),
            positions,
            sizes,
          ),
      ];
      final lower = [
        for (final id in ['end', 'pursuits', 'isaiah'])
          conceptMapConnector(
            ConceptMapEdge(from: 'james11', to: id),
            positions,
            sizes,
          ),
      ];
      for (var a = 0; a < upper.length; a++) {
        for (var b = 0; b < lower.length; b++) {
          if (a == 2 && b == 2) continue; // Both actually connect to Isaiah.
          expect(upper[a], isNotEmpty);
          expect(lower[b], isNotEmpty);
          for (var i = 1; i < upper[a].length; i++) {
            for (var j = 1; j < lower[b].length; j++) {
              expect(
                Rect.fromPoints(upper[a][i - 1], upper[a][i])
                    .inflate(1.5)
                    .overlaps(
                      Rect.fromPoints(
                        lower[b][j - 1],
                        lower[b][j],
                      ).inflate(1.5),
                    ),
                isFalse,
                reason: 'Unrelated branches must not look connected',
              );
            }
          }
        }
      }
    },
  );

  test('branches from one card share a trunk without crossing each other', () {
    const positions = {
      'node13': Offset(80, 300),
      'node2': Offset(430, 80),
      'node3': Offset(430, 260),
      'node9': Offset(430, 520),
      'node10': Offset(430, 800),
    };
    const sizes = {
      'node13': Size(300, 50),
      'node2': Size(300, 120),
      'node3': Size(300, 80),
      'node9': Size(300, 220),
      'node10': Size(300, 60),
    };
    final routes = [
      for (final id in ['node2', 'node3', 'node9', 'node10'])
        conceptMapConnector(
          ConceptMapEdge(from: 'node13', to: id),
          positions,
          sizes,
        ),
    ];
    final trunks = <double>{};
    final horizontal = <(Offset, Offset)>[];
    final vertical = <(Offset, Offset)>[];
    for (final route in routes) {
      expect(route, isNotEmpty);
      for (var i = 1; i < route.length; i++) {
        final a = route[i - 1];
        final b = route[i];
        if (a == b) continue;
        if (a.dx == b.dx) {
          trunks.add(a.dx);
          vertical.add((a, b));
        } else {
          horizontal.add((a, b));
        }
      }
    }
    expect(trunks, hasLength(1));
    for (final (a, b) in horizontal) {
      for (final (c, d) in vertical) {
        final crosses =
            c.dx > math.min(a.dx, b.dx) &&
            c.dx < math.max(a.dx, b.dx) &&
            a.dy > math.min(c.dy, d.dy) &&
            a.dy < math.max(c.dy, d.dy);
        expect(crosses, isFalse);
      }
    }
  });

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
    expect(
      tester.getSize(find.byType(Card).first).width,
      greaterThanOrEqualTo(290),
    );
    expect(positions['a']!.dx, lessThanOrEqualTo(430));
    expect(positions['b']!.dx, lessThanOrEqualTo(430));
    final canvas = tester.widget<SizedBox>(
      find
          .descendant(
            of: find.byType(InteractiveViewer),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    for (final position in positions.values) {
      expect(position.dx + 300, lessThanOrEqualTo(canvas.width!));
      expect(position.dy + 80, lessThanOrEqualTo(canvas.height!));
    }
  });

  testWidgets('unchanged cards keep their bounds when toggling edit mode', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final document = ConceptMapDocument.fromMermaid('''
flowchart TD
  key[A short key point]:::keyPoint
  verse[James 1:9]:::passage
  note[A longer note that wraps onto multiple lines with enough words to fill the card]:::note
  empty[]:::note
  rich[The Rich Should Glory in Their Humiliation]:::keyPoint
  boundary[XXXXXXXXXXXXXXXXXXX]:::note
  key ---> verse
  verse ---> note
''');
    Future<void> render(bool editing, double textScale) async {
      await tester.pumpWidget(
        host(
          Scaffold(
            body: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: ConceptMapEditor(
                  document: document,
                  editing: editing,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    List<Rect> bounds() => [
      for (final card in find.byType(Card).evaluate())
        tester.getRect(find.byWidget(card.widget)),
    ];
    // The near-full boundary label catches an extra line caused by caret space.
    for (final scale in [1.0, 1.5, 2.0]) {
      await render(false, scale);
      final original = bounds();
      await render(true, scale);
      expect(bounds(), original);
      await tester.tap(find.widgetWithText(TextField, 'A short key point'));
      await tester.pumpAndSettle();
      expect(bounds(), original);
      await render(false, scale);
      expect(bounds(), original);
    }
  });

  testWidgets('pinching and long-pressing labels never open a card menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Scaffold(
          body: ConceptMapEditor(
            document: ConceptMapDocument.fromMermaid(
              'flowchart TD\n a[Hold here]:::note',
            ),
            editing: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = await tester.startGesture(
      tester.getCenter(find.text('Hold here')),
      pointer: 1,
    );
    await tester.pump(const Duration(milliseconds: 100));
    final second = await tester.startGesture(
      const Offset(500, 250),
      pointer: 2,
    );
    await second.moveTo(const Offset(650, 350));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!
          .value
          .getMaxScaleOnAxis(),
      greaterThan(1),
    );
    await second.up();
    await first.up();
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Hold here'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('double-tap selection can copy and paste editable labels', (
    tester,
  ) async {
    var clipboard = '';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          clipboard = (call.arguments as Map)['text'] as String;
          return null;
        case 'Clipboard.getData':
          return {'text': clipboard};
        case 'Clipboard.hasStrings':
          return {'value': clipboard.isNotEmpty};
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    var document = ConceptMapDocument.fromMermaid(
      'flowchart TD\n a[Alpha Beta]:::note',
    );
    await tester.pumpWidget(
      host(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ConceptMapEditor(
              document: document,
              editing: true,
              onChanged: (value) => setState(() => document = value),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final text = find.byType(EditableText);
    final point = tester.getTopLeft(text) + const Offset(20, 8);
    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(point);
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Cut'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(clipboard, 'Alpha');
    await tester.pump(const Duration(milliseconds: 500));
    final editable = tester.state<EditableTextState>(text).renderEditable;
    final secondWord = editable.localToGlobal(
      editable.getLocalRectForCaret(const TextPosition(offset: 8)).center,
    );
    await tester.tapAt(secondWord);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(secondWord);
    await tester.pumpAndSettle();
    final controller = tester.widget<EditableText>(text).controller;
    expect(controller.selection.textInside(controller.text), 'Beta');
    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();
    expect(document.nodes.single.label, 'Alpha Alpha');
  });

  testWidgets(
    'selected card toolbar stays usable in landscape with large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(640, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final scale in [1.0, 2.0]) {
        late StudyNote note;
        await tester.runAsync(() async {
          note = await notesService.createNote(title: 'Landscape');
          await notesService.updateConceptMap(
            note.id,
            'flowchart TD\n a[Landscape card]:::note',
          );
          note = (await notesService.getNote(note.id))!;
        });
        await tester.pumpWidget(
          host(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: StudyNotesDetailPage(key: ValueKey(scale), note: note),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Concept Map'));
        await tester.tap(find.byTooltip('Edit'));
        await tester.pumpAndSettle();
        expect(find.text('Delete'), findsNothing);
        await selectCard(tester, 'Landscape card');
        await tester.ensureVisible(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ConceptMapEditor>(find.byType(ConceptMapEditor))
              .document
              .nodes,
          isEmpty,
        );
        expect(find.text('Delete'), findsNothing);
        expect(find.text('Connect'), findsNothing);
        expect(find.text('Key point'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'keyboard selects cards for toolbar actions and connects to an editable label',
    (tester) async {
      late StudyNote note;
      await tester.runAsync(() async {
        note = await notesService.createNote(title: 'Keyboard');
        await notesService.updateConceptMap(note.id, '''
flowchart TD
 a[James 1:9]:::passage
 b[The Lowly]:::note
''');
        note = (await notesService.getNote(note.id))!;
      });
      await tester.pumpWidget(host(StudyNotesDetailPage(note: note)));
      await tester.tap(find.text('Concept Map'));
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      // Focus the passage through the normal traversal order.
      for (
        var i = 0;
        i < 10 && find.text('Show passage').evaluate().isEmpty;
        i++
      ) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }
      await tester.pumpAndSettle();
      expect(find.text('Show passage'), findsOneWidget);
      for (
        var i = 0;
        i < 10 && !Focus.of(tester.element(find.text('Connect'))).hasFocus;
        i++
      ) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
      }
      expect(Focus.of(tester.element(find.text('Connect'))).hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      final label = tester.widget<EditableText>(find.byType(EditableText));
      for (var i = 0; i < 10 && !label.focusNode.hasFocus; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }
      expect(label.focusNode.hasFocus, isTrue);
      await tester.pumpAndSettle();
      ConceptMapDocument document() => tester
          .widget<ConceptMapEditor>(find.byType(ConceptMapEditor))
          .document;
      expect(document().edges, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(document().edges.single.from, 'a');
      expect(document().edges.single.to, 'b');
    },
  );

  testWidgets('adding cards centers the viewport without changing zoom', (
    tester,
  ) async {
    late StudyNote note;
    await tester.runAsync(() async {
      note = await notesService.createNote(title: 'Wisdom', passage: passage);
      await notesService.updateConceptMap(
        note.id,
        ConceptMapDocument(
          nodes: [
            for (var i = 1; i <= 6; i++)
              ConceptMapNode(
                id: 'node$i',
                type: ConceptMapNodeType.note,
                label: 'Existing $i',
              ),
          ],
        ).toMermaid(),
      );
      note = (await notesService.getNote(note.id))!;
    });
    await tester.pumpWidget(host(StudyNotesDetailPage(note: note)));
    await tester.tap(find.text('Concept Map'));
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    final viewer = find.byType(InteractiveViewer);
    final transform = tester
        .widget<InteractiveViewer>(viewer)
        .transformationController!;
    transform.value = Matrix4.diagonal3Values(1.5, 1.5, 1.5)
      ..setTranslationRaw(-140, -70, 0);
    await tester.pumpAndSettle();
    for (final type in ['Note', 'Key point']) {
      await tester.tap(find.text(type).last);
      await tester.pumpAndSettle();
      final center = tester.getRect(find.byType(Card).last).center;
      expect((center - tester.getRect(viewer).center).distance, lessThan(1));
      expect(transform.value.getMaxScaleOnAxis(), 1.5);
    }
    await tester.tap(find.text('Passage'));
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byType(StudyNotesDetailPage)),
    ).pop(otherPassage);
    await tester.pumpAndSettle();
    final addedPassage = tester
        .widget<ConceptMapEditor>(find.byType(ConceptMapEditor))
        .document
        .nodes
        .last;
    expect(addedPassage.type, ConceptMapNodeType.passage);
    expect(addedPassage.passage, otherPassage);
    expect(transform.value.getMaxScaleOnAxis(), 1.5);
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Save'));
      await database
          .watchStudyNotes()
          .firstWhere(
            (notes) => notesService
                .passagesFor(
                  notes.single.copyWith(conceptMap: const Value(null)),
                )
                .contains(otherPassage),
          )
          .timeout(const Duration(seconds: 5));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Chip, 'John 3:16-16'), findsOneWidget);
  });

  testWidgets('plus buttons connect new cards only when a card is selected', (
    tester,
  ) async {
    for (final selected in [false, true]) {
      late StudyNote note;
      await tester.runAsync(() async {
        note = await notesService.createNote(title: 'New branches');
        await notesService.updateConceptMap(note.id, '''
flowchart TD
  a[Other card]:::keyPoint
  b[Selected parent]:::note
''');
        note = (await notesService.getNote(note.id))!;
      });
      await tester.pumpWidget(
        host(StudyNotesDetailPage(key: ValueKey(selected), note: note)),
      );
      await tester.tap(find.text('Concept Map'));
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      if (selected) {
        await selectCard(tester, 'Selected parent');
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();
      }
      ConceptMapEditor editor() =>
          tester.widget<ConceptMapEditor>(find.byType(ConceptMapEditor));
      final addedIds = <String>[];
      for (final type in ['Note', 'Key point', 'Passage']) {
        await tester.ensureVisible(find.text(type).last);
        await tester.tap(find.text(type).last);
        await tester.pumpAndSettle();
        if (type == 'Passage') {
          Navigator.of(
            tester.element(find.byType(StudyNotesDetailPage)),
          ).pop(otherPassage);
          await tester.pumpAndSettle();
        }
        final document = editor().document;
        addedIds.add(document.nodes.last.id);
        expect(document.nodes, hasLength(2 + addedIds.length));
        expect(document.edges.map((edge) => (edge.from, edge.to)), [
          if (selected)
            for (final id in addedIds) ('b', id),
        ]);
        expect(editor().selectedNodeId, selected ? 'b' : null);
      }
      expect(editor().document.nodes.last.passage, otherPassage);
      final beforeCancel = editor().document.toMermaid();
      await tester.ensureVisible(find.text('Passage'));
      await tester.tap(find.text('Passage'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(StudyNotesDetailPage))).pop();
      await tester.pumpAndSettle();
      expect(editor().document.toMermaid(), beforeCancel);
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Save'));
        final saved = (await notesService.getNote(note.id))!;
        expect(saved.conceptMap, beforeCancel);
      });
      await tester.pumpAndSettle();
    }
  });

  testWidgets('connect uses the selected card and one destination tap', (
    tester,
  ) async {
    late StudyNote note;
    await tester.runAsync(() async {
      note = await notesService.createNote(title: 'Wisdom', passage: passage);
      await notesService.updateConceptMap(note.id, '''
flowchart TD
  a[Source]:::note
  b[Destination]:::keyPoint
  c[James]:::passage
  class c showPassage
  click c "passage://Jas/1/9/11"
  c ---> b
''');
      note = (await notesService.getNote(note.id))!;
    });
    await tester.pumpWidget(host(StudyNotesDetailPage(note: note)));
    await tester.tap(find.text('Concept Map'));
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Connect boxes'), findsNothing);
    final cardBounds = [
      for (var i = 0; i < 3; i++) tester.getRect(find.byType(Card).at(i)),
    ];
    await selectCard(tester, 'Source');
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('Disconnect'),
              matching: find.byWidgetPredicate(
                (widget) => widget is TextButton,
              ),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Passage text'), findsOneWidget);
    expect([
      for (var i = 0; i < 3; i++) tester.getRect(find.byType(Card).at(i)),
    ], cardBounds);
    await tester.tap(find.text('Source'));
    await tester.tap(find.text('Destination'));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Save'));
      final saved = await database.watchStudyNotes().firstWhere(
        (notes) => ConceptMapDocument.fromMermaid(
          notes.single.conceptMap!,
        ).edges.any((edge) => edge.from == 'a'),
      );
      final edge = ConceptMapDocument.fromMermaid(
        saved.single.conceptMap!,
      ).edges.singleWhere((edge) => edge.from == 'a');
      expect(edge.from, 'a');
      expect(edge.to, 'b');
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextField, 'Source'));
    await tester.pumpAndSettle();
    await selectCard(tester, 'Source');
    await tester.ensureVisible(find.text('Disconnect'));
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Destination'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Save'));
      final saved = await database.watchStudyNotes().firstWhere(
        (notes) => ConceptMapDocument.fromMermaid(
          notes.single.conceptMap!,
        ).edges.every((edge) => edge.from != 'a'),
      );
      expect(
        ConceptMapDocument.fromMermaid(saved.single.conceptMap!).nodes,
        hasLength(3),
      );
      final remaining = ConceptMapDocument.fromMermaid(
        saved.single.conceptMap!,
      ).edges.single;
      expect(remaining.from, 'c');
      expect(remaining.to, 'b');
    });
    await tester.pumpAndSettle();
  });

  testWidgets(
    'stale editors preserve synced fields and unchanged saves stay clean',
    (tester) async {
      late StudyNote note;
      await tester.runAsync(() async {
        note = await notesService.createNote(title: 'Wisdom');
        await notesService.updateNotes(note.id, 'Original');
        note = (await notesService.getNote(note.id))!;
        await database.acknowledgeChanges(
          (await database.pendingChanges()).map((c) => c.id),
        );
      });
      const remoteMap = 'flowchart TD\n  remote[Remote insight]';
      for (final editText in [false, true]) {
        await tester.pumpWidget(
          host(StudyNotesDetailPage(key: ValueKey(editText), note: note)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Edit'));
        await tester.pumpAndSettle();
        if (editText) {
          await tester.enterText(find.byType(TextField), 'Local text edit');
        }
        late StudyNote remote;
        await tester.runAsync(() async {
          remote = note.copyWith(
            notes: const Value('Remote text'),
            conceptMap: const Value(remoteMap),
            updatedAt: note.updatedAt.add(const Duration(minutes: 1)),
          );
          await database.mergeRemoteStudyNote(remote.toCompanion(false));
          await tester.tap(find.byTooltip('Save'));
        });
        // Native SQLite runs outside the widget-test fake clock.
        for (
          var attempt = 0;
          attempt < 50 && find.byTooltip('Save').evaluate().isNotEmpty;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.byTooltip('Edit'), findsOneWidget);
        await tester.runAsync(() async {
          final saved = (await notesService.getNote(note.id))!;
          expect(saved.notes, editText ? 'Local text edit' : 'Remote text');
          expect(saved.conceptMap, remoteMap);
          if (!editText) {
            expect(saved.updatedAt, remote.updatedAt);
            expect(await database.pendingChanges(), isEmpty);
          }
          expect(await database.getAllResults(), hasLength(1));
        });
      }
    },
  );

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
        notesService.onLocalChange = () async {
          saved.complete();
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
    await selectCard(tester, 'Jas 1:9-11');
    await tester.ensureVisible(find.text('Show passage'));
    await tester.tap(find.text('Show passage'));
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
    expect(
      find.textContaining('Saved changes record one study session per day.'),
      findsOneWidget,
    );
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

  testWidgets(
    'add passage records a daily note session and keeps the edit FAB',
    (tester) async {
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
      expect(find.text('Show passage'), findsNothing);
      await selectCard(tester, 'John 3:16-16');
      await tester.ensureVisible(find.text('Show passage'));
      await tester.tap(find.text('Show passage'));
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
      await selectCard(tester, 'Jas 1:9-11');
      await tester.ensureVisible(find.text('Show passage'));
      await tester.tap(find.text('Show passage'));
      await tester.pumpAndSettle();
      expect(find.text('Passage text'), findsNWidgets(2));
      expect(find.text('Passage'), findsOneWidget);
      expect(find.byTooltip('Save'), findsOneWidget);
      await selectCard(tester, 'John 3:16-16');
      await tester.ensureVisible(find.text('Hide passage'));
      await tester.tap(find.text('Hide passage'));
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
        final session = (await database.getAllResults()).single;
        expect(session.studyNoteId, note.clientId);
        expect(session.bookId, isNull);
      });
      expect(find.text('Add passage'), findsOneWidget);
      expect(find.byTooltip('Save'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Keep learning');
      await tester.runAsync(() async {
        final saved = Completer<void>();
        notesService.onLocalChange = () async {
          saved.complete();
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
    },
  );

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
      expect(
        (await database.getAllResults()).single.studyNoteId,
        note.clientId,
      );
    });
  });
}
