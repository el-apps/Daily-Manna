import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

const databaseName = 'daily_manna';

enum ResultType { memorization, recitation, study }

class Results extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();
  IntColumn get type => intEnum<ResultType>()();
  TextColumn get bookId => text()();
  IntColumn get startChapter => integer()();
  IntColumn get startVerse => integer()();
  IntColumn get endChapter => integer().nullable()();
  IntColumn get endVerse => integer().nullable()();
  RealColumn get score => real()();
  IntColumn get attempts => integer().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get clientId => text().unique().clientDefault(newClientId)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
}

class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {entityType, entityId},
  ];
}

class SyncMetadata extends Table {
  IntColumn get id => integer()();
  TextColumn get cursor => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Results, SyncOutbox, SyncMetadata])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing with an in-memory database.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(results, results.notes);
      }
      if (from < 3) {
        // Existing rows get deterministic IDs, so repeated migrations/imports
        // cannot create duplicate server records.
        await customStatement('ALTER TABLE results ADD COLUMN client_id TEXT');
        await customStatement(
          'ALTER TABLE results ADD COLUMN updated_at INTEGER',
        );
        await customStatement(
          "UPDATE results SET client_id = 'legacy-' || id, "
          'updated_at = timestamp',
        );
        await customStatement(
          'CREATE UNIQUE INDEX results_client_id ON results (client_id)',
        );
        await m.createTable(syncOutbox);
        await m.createTable(syncMetadata);
        await customStatement('''
          INSERT INTO sync_outbox (entity_type, entity_id, operation, created_at)
          SELECT 'result', client_id, 'upsert', updated_at
          FROM results
        ''');
      }
    },
  );

  static QueryExecutor _openConnection() => driftDatabase(
    name: databaseName,
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );

  /// Inserts a local result and records it for a later push atomically.
  Future<int> insertResult(ResultsCompanion result) => transaction(() async {
    final now = DateTime.now().toUtc();
    final clientId = result.clientId.present
        ? result.clientId.value
        : newClientId();
    final id = await into(results).insert(
      result.copyWith(
        clientId: Value(clientId),
        updatedAt: result.updatedAt.present ? result.updatedAt : Value(now),
      ),
    );
    await _enqueueResult(clientId, 'upsert', now);
    return id;
  });

  /// Update notes for a result.
  Future<void> updateResultNotes(int id, String? notes) =>
      transaction(() async {
        final row = await (select(
          results,
        )..where((r) => r.id.equals(id))).getSingle();
        final now = DateTime.now().toUtc();
        await (update(results)..where((r) => r.id.equals(id))).write(
          ResultsCompanion(notes: Value(notes), updatedAt: Value(now)),
        );
        await _enqueueResult(row.clientId, 'upsert', now);
      });

  Future<void> _enqueueResult(
    String clientId,
    String operation,
    DateTime now,
  ) => into(syncOutbox).insert(
    SyncOutboxCompanion.insert(
      entityType: 'result',
      entityId: clientId,
      operation: operation,
      createdAt: now,
    ),
    mode: InsertMode.insertOrReplace,
  );

  Future<List<SyncOutboxData>> pendingChanges() => select(syncOutbox).get();

  Future<void> acknowledgeChanges(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    await (delete(syncOutbox)..where((row) => row.id.isIn(ids))).go();
  }

  Future<Result?> resultByClientId(String clientId) => (select(
    results,
  )..where((row) => row.clientId.equals(clientId))).getSingleOrNull();

  Future<bool> hasPendingChange(String clientId) async =>
      await (select(
        syncOutbox,
      )..where((row) => row.entityId.equals(clientId))).getSingleOrNull() !=
      null;

  /// Applies a server value without feeding it back into the outbox.
  Future<void> mergeRemoteResult(ResultsCompanion remote) async {
    final existing = await resultByClientId(remote.clientId.value);
    if (existing != null &&
        !remote.updatedAt.value.isAfter(existing.updatedAt)) {
      return;
    }
    await into(results).insertOnConflictUpdate(remote);
  }

  Future<void> deleteRemoteResult(String clientId) =>
      (delete(results)..where((row) => row.clientId.equals(clientId))).go();

  Future<String?> getSyncCursor() async => (await (select(
    syncMetadata,
  )..where((row) => row.id.equals(1))).getSingleOrNull())?.cursor;

  Future<void> setSyncCursor(String? cursor) =>
      into(syncMetadata).insertOnConflictUpdate(
        SyncMetadataCompanion.insert(id: const Value(1), cursor: Value(cursor)),
      );

  // Get all results, newest first
  Future<List<Result>> getAllResults() =>
      (select(results)..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).get();

  // Watch all results (reactive stream)
  Stream<List<Result>> watchAllResults() => (select(
    results,
  )..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).watch();

  /// Watch all study results (for study log history).
  Stream<List<Result>> watchStudyResults() =>
      (select(results)
            ..where((r) => r.type.equals(ResultType.study.index))
            ..orderBy([(r) => OrderingTerm.desc(r.timestamp)]))
          .watch();

  // Get results for a specific verse
  Future<List<Result>> getResultsForVerse(
    String bookId,
    int chapter,
    int verse,
  ) =>
      (select(results)..where(
            (t) =>
                t.bookId.equals(bookId) &
                t.startChapter.equals(chapter) &
                t.startVerse.equals(verse),
          ))
          .get();

  // Get unique verses that have been practiced
  Future<List<({String bookId, int chapter, int verse})>>
  getUniqueVersesPracticed() async {
    final query = selectOnly(results, distinct: true)
      ..addColumns([results.bookId, results.startChapter, results.startVerse]);
    final rows = await query.get();
    return rows
        .map(
          (row) => (
            bookId: row.read(results.bookId)!,
            chapter: row.read(results.startChapter)!,
            verse: row.read(results.startVerse)!,
          ),
        )
        .toList();
  }

  // Get results from today (since midnight)
  Future<List<Result>> getTodayResults() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    return (select(results)
          ..where((t) => t.timestamp.isBiggerOrEqualValue(midnight))
          ..orderBy([
            (t) => OrderingTerm.desc(t.timestamp),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .get();
  }
}

String newClientId([Random? random]) {
  final bytes = List<int>.generate(
    16,
    (_) => (random ?? Random.secure()).nextInt(256),
  );
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
