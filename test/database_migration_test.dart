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
    expect(await database.pendingChanges(), isEmpty);

    await database.close();
    await directory.delete(recursive: true);
  });
}
