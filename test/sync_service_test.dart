import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/services/sync_service.dart';
import 'package:daily_manna/services/study_notes_service.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSyncTransport implements SyncTransport {
  final calls = <List<Map<String, dynamic>>>[];
  final tokens = <String?>[];
  final responses = <SyncResponse>[];

  @override
  Future<SyncResponse> exchange({
    required String clientId,
    required int cursor,
    required int baseCursor,
    required List<Map<String, dynamic>> changes,
    String? authToken,
  }) async {
    calls.add(changes);
    tokens.add(authToken);
    return responses.removeAt(0);
  }
}

void main() {
  late AppDatabase database;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('local writes have stable IDs and coalesce in the outbox', () async {
    final id = await database.insertResult(
      ResultsCompanion.insert(
        timestamp: DateTime(2026),
        type: ResultType.study,
        bookId: 'Gen',
        startChapter: 1,
        startVerse: 1,
        score: 1,
      ),
    );
    final original = (await database.getAllResults()).single;
    await database.updateResultNotes(id, 'updated');

    expect(original.clientId, isNotEmpty);
    expect((await database.getAllResults()).single.clientId, original.clientId);
    expect(await database.pendingChanges(), hasLength(1));
  });

  test('sync pulls, merges, pushes pending writes, then pulls again', () async {
    await database.insertResult(
      ResultsCompanion.insert(
        timestamp: DateTime.utc(2026),
        type: ResultType.study,
        bookId: 'Gen',
        startChapter: 1,
        startVerse: 1,
        score: 1,
      ),
    );
    final transport = FakeSyncTransport()
      ..responses.addAll([
        SyncResponse(cursor: 2, changes: [_remoteChange('remote-result')]),
        const SyncResponse(cursor: 3, changes: []),
        const SyncResponse(cursor: 3, changes: []),
      ]);

    final service = SyncService(database, transport: transport);
    final firstClientId = await service.getClientId();
    expect(await service.getClientId(), firstClientId);
    await service.sync();

    expect(transport.calls, hasLength(3));
    expect(transport.calls[0], isEmpty);
    expect(transport.calls[1], hasLength(1));
    expect(transport.calls[2], isEmpty);
    expect(await database.pendingChanges(), isEmpty);
    expect(await database.resultByClientId('remote-result'), isNotNull);
    expect(await database.getSyncCursor(), '3');
  });

  test('sync supplies the current authentication token', () async {
    final transport = FakeSyncTransport()
      ..responses.addAll(const [
        SyncResponse(cursor: 0, changes: []),
        SyncResponse(cursor: 0, changes: []),
      ]);
    final service = SyncService(
      database,
      transport: transport,
      authTokenProvider: () async => 'saved-token',
    );

    await service.sync();

    expect(transport.tokens, everyElement('saved-token'));
  });

  test('study links survive sync with different device-local note IDs', () async {
    final note = await StudyNotesService(database).createNote(
      title: 'Wisdom',
      passage: const ScriptureRangeRef(
        bookId: 'Jas',
        chapter: 1,
        startVerse: 9,
      ),
    );
    await ResultsService(database).addStudyResult(
      const ScriptureRangeRef(bookId: 'Jas', chapter: 1, startVerse: 10),
      studyNoteId: note.clientId,
    );
    final push = FakeSyncTransport()
      ..responses.addAll(const [
        SyncResponse(cursor: 0, changes: []),
        SyncResponse(cursor: 2, changes: []),
        SyncResponse(cursor: 2, changes: []),
      ]);
    await SyncService(database, transport: push).sync();
    final outgoing = push.calls[1];
    final resultChange = outgoing.singleWhere(
      (change) => change['type'] == 'result',
    );
    final noteChange = outgoing.singleWhere(
      (change) => change['type'] == 'study_note',
    );
    expect(resultChange['data']['studyNoteId'], note.clientId);

    final otherDevice = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(otherDevice.close);
    await StudyNotesService(otherDevice).createNote(
      title: 'Unrelated local note',
      passage: const ScriptureRangeRef(
        bookId: 'Gen',
        chapter: 2,
        startVerse: 1,
      ),
    );
    await otherDevice.acknowledgeChanges(
      (await otherDevice.pendingChanges()).map((change) => change.id),
    );
    final pull = FakeSyncTransport()
      ..responses.addAll([
        // A session may arrive before its note; linking must not depend on order.
        SyncResponse(cursor: 2, changes: [resultChange, noteChange]),
        const SyncResponse(cursor: 2, changes: []),
      ]);
    await SyncService(otherDevice, transport: pull).sync();
    final linked = (await otherDevice.getAllResults()).single;
    final remoteNote = await otherDevice.studyNoteByClientId(
      linked.studyNoteId!,
    );
    expect(remoteNote!.title, 'Wisdom');
    expect(remoteNote.id, isNot(note.id));
    expect(remoteNote.clientId, note.clientId);
  });

  test('sync can merge the server echo of a pushed local result', () async {
    await database.insertResult(
      ResultsCompanion.insert(
        timestamp: DateTime.utc(2026),
        type: ResultType.study,
        bookId: 'Jas',
        startChapter: 1,
        startVerse: 9,
        score: 1,
        notes: const Value('copy to outline'),
        clientId: const Value('legacy-1087'),
        updatedAt: Value(DateTime.utc(2026, 9, 7, 7, 28)),
      ),
    );
    final transport = FakeSyncTransport()
      ..responses.addAll([
        const SyncResponse(cursor: 0, changes: []),
        SyncResponse(
          cursor: 1,
          changes: [
            _remoteChange(
              'legacy-1087',
              updatedAt: '2026-09-07T07:30:00Z',
              resultType: 'study',
              bookId: 'Jas',
              startChapter: 1,
              startVerse: 9,
              score: 1,
              notes: 'copy to outline',
            ),
          ],
        ),
        SyncResponse(
          cursor: 1,
          changes: [
            _remoteChange(
              'legacy-1087',
              updatedAt: '2026-09-07T07:30:00Z',
              resultType: 'study',
              bookId: 'Jas',
              startChapter: 1,
              startVerse: 9,
              score: 1,
              notes: 'copy to outline',
            ),
          ],
        ),
      ]);

    await SyncService(database, transport: transport).sync();

    final result = (await database.getAllResults()).single;
    expect(result.clientId, 'legacy-1087');
    expect(result.notes, 'copy to outline');
    expect(result.updatedAt.toUtc(), DateTime.utc(2026, 9, 7, 7, 30));
  });
}

Map<String, dynamic> _remoteChange(
  String id, {
  String? updatedAt,
  String resultType = 'recitation',
  String bookId = 'Psa',
  int startChapter = 23,
  int startVerse = 1,
  double score = .9,
  String? notes,
}) => {
  'type': 'result',
  'id': id,
  'version': 2,
  'data': {
    'timestamp': DateTime.utc(2025).toIso8601String(),
    'resultType': resultType,
    'bookId': bookId,
    'startChapter': startChapter,
    'startVerse': startVerse,
    'endChapter': null,
    'endVerse': 6,
    'score': score,
    'attempts': null,
    'notes': notes,
    'updatedAt': updatedAt ?? DateTime.utc(2025).toIso8601String(),
  },
};
