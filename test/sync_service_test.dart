import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/services/sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSyncTransport implements SyncTransport {
  final calls = <List<Map<String, dynamic>>>[];
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
}

Map<String, dynamic> _remoteChange(String id) => {
  'type': 'result',
  'id': id,
  'version': 2,
  'data': {
    'timestamp': DateTime.utc(2025).toIso8601String(),
    'resultType': 'recitation',
    'bookId': 'Psa',
    'startChapter': 23,
    'startVerse': 1,
    'endChapter': null,
    'endVerse': 6,
    'score': .9,
    'attempts': null,
    'notes': null,
    'updatedAt': DateTime.utc(2025).toIso8601String(),
  },
};
