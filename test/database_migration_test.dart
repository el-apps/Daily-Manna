import 'dart:io';

import 'package:daily_manna/services/database/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('v2 migration assigns stable sync fields to existing results', () async {
    final directory = await Directory.systemTemp.createTemp('manna-migration');
    final file = File('${directory.path}/database.sqlite');
    final old = sqlite.sqlite3.open(file.path);
    old.execute('''
      CREATE TABLE results (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        type INTEGER NOT NULL,
        book_id TEXT NOT NULL,
        start_chapter INTEGER NOT NULL,
        start_verse INTEGER NOT NULL,
        end_chapter INTEGER,
        end_verse INTEGER,
        score REAL NOT NULL,
        attempts INTEGER,
        notes TEXT
      )
    ''');
    old.execute('''
      INSERT INTO results (
        timestamp, type, book_id, start_chapter, start_verse, score
      ) VALUES (1704067200, 2, 'Gen', 1, 1, 1.0)
    ''');
    old.execute('PRAGMA user_version = 2');
    old.dispose();

    final database = AppDatabase.forTesting(NativeDatabase(file));
    final result = (await database.getAllResults()).single;
    expect(result.clientId, 'legacy-1');
    expect(result.updatedAt, result.timestamp);
    expect(result.studyNoteId, isNull);
    final pending = await database.pendingChanges();
    expect(pending, hasLength(1));
    expect(pending.single.entityId, 'legacy-1');
    expect(pending.single.operation, 'upsert');

    await database.close();
    await directory.delete(recursive: true);
  });

  for (final version in [6, 7, 8, 9]) {
    test(
      'v$version migration preserves workspaces and defaults notes to active',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'manna-workspace-migration',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/database.sqlite');
        final old = sqlite.sqlite3.open(file.path);
        old.execute('''
      CREATE TABLE results (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL, type INTEGER NOT NULL,
        book_id TEXT${version >= 9 ? '' : ' NOT NULL'}, start_chapter INTEGER${version >= 9 ? '' : ' NOT NULL'},
        start_verse INTEGER${version >= 9 ? '' : ' NOT NULL'}, end_chapter INTEGER, end_verse INTEGER,
        score REAL NOT NULL, attempts INTEGER, notes TEXT,
        client_id TEXT NOT NULL UNIQUE, updated_at INTEGER NOT NULL
      );
      CREATE TABLE study_notes (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL, notes TEXT, concept_map TEXT,
        passages TEXT NOT NULL, created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL, client_id TEXT NOT NULL UNIQUE
      );
      INSERT INTO results (
        timestamp, type, book_id, start_chapter, start_verse, score,
        notes, client_id, updated_at
      ) VALUES (1704067200, 2, 'Jas', 1, 9, 1.0, 'Session text', 'session-1', 1704067200);
      INSERT INTO study_notes (
        title, notes, concept_map, passages, created_at, updated_at, client_id
      ) VALUES ('Wisdom', 'Workspace text', 'flowchart TD', '[]', 1704067200, 1704067200, 'note-1');
      CREATE TABLE sync_outbox (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL, entity_id TEXT NOT NULL,
        operation TEXT NOT NULL, created_at INTEGER NOT NULL,
        UNIQUE(entity_type, entity_id)
      );
    ''');
        if (version >= 7) {
          old.execute('ALTER TABLE results ADD COLUMN study_note_id TEXT');
        }
        if (version >= 8) {
          old.execute(
            'ALTER TABLE study_notes ADD COLUMN archived INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (version == 9) {
          old.execute('''
            INSERT INTO results (
              timestamp, type, score, study_note_id, client_id, updated_at
            ) VALUES (1704067200, 2, 1.0, 'note-1', 'legacy-note-session', 1704067200)
          ''');
        }
        old.execute('PRAGMA user_version = $version');
        old.dispose();
        final database = AppDatabase.forTesting(NativeDatabase(file));
        addTearDown(database.close);
        final result = (await database.getAllResults()).singleWhere(
          (r) => r.clientId == 'session-1',
        );
        expect(result.studyNoteId, isNull);
        expect(result.notes, 'Session text');
        expect(result.clientId, 'session-1');
        final note = (await database.getStudyNotes()).single;
        expect(note.title, 'Wisdom');
        expect(note.notes, 'Workspace text');
        expect(note.conceptMap, 'flowchart TD');
        expect(note.clientId, 'note-1');
        expect(note.archived, isFalse);
        if (version == 9) {
          final pending = await database.pendingChanges();
          expect(pending.map((c) => '${c.entityType}:${c.operation}').toSet(), {
            'result:delete',
            'study_session:upsert',
          });
          expect(
            pending.every((c) => c.entityId == 'legacy-note-session'),
            isTrue,
          );
          expect(
            await database.hasPendingChange('legacy-note-session'),
            isTrue,
          );
        }
        await database.recordStudyNoteSession(note.clientId);
        final sessions = await database.getAllResults();
        expect(sessions, hasLength(version == 9 ? 3 : 2));
        expect(sessions.first.bookId, isNull);
        expect(sessions.first.studyNoteId, note.clientId);
      },
    );
  }
}
