import 'package:daily_manna/services/database_export_models.dart';
import 'dart:convert';

import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/services/database_export_web.dart' as web;
import 'package:daily_manna/services/study_notes_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'web backup includes archived and unstudied notes with stable session links',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final service = StudyNotesService(database);
      final note = await service.createNote(title: 'Stewardship');
      await service.updateNotes(note.id, 'Private note text\nSecond line');
      await service.updateConceptMap(
        note.id,
        'flowchart TD\n  a[Faithfulness]',
      );
      await service.setArchived(note.id, true);
      final untouched = await service.createNote(title: 'Unstudied note');
      final saved = (await service.getNote(note.id))!;
      final session = (await database.getAllResults()).single;
      final export = await web.DatabaseExportService(database).exportDatabase();
      final tables =
          (jsonDecode(await export.file.readAsString()) as Map)['tables']
              as Map;
      expect(tables['study_notes'], hasLength(2));
      final notes = (tables['study_notes'] as List).cast<Map>();
      expect(notes.singleWhere((row) => row['clientId'] == saved.clientId), {
        'id': saved.id,
        'clientId': saved.clientId,
        'title': 'Stewardship',
        'notes': 'Private note text\nSecond line',
        'conceptMap': 'flowchart TD\n  a[Faithfulness]',
        'passages': '[]',
        'archived': true,
        'createdAt': saved.createdAt.toIso8601String(),
        'updatedAt': saved.updatedAt.toIso8601String(),
      });
      expect(
        notes.singleWhere(
          (row) => row['clientId'] == untouched.clientId,
        )['notes'],
        isNull,
      );
      final result = (tables['results'] as List).single as Map;
      expect(result['clientId'], session.clientId);
      expect(result['studyNoteId'], saved.clientId);
      expect(result['bookId'], isNull);
      expect(result['updatedAt'], session.updatedAt.toIso8601String());
    },
  );

  group('buildDatabaseExportFileName', () {
    test('builds sqlite file names with zero-padded local timestamps', () {
      final fileName = buildDatabaseExportFileName(
        DateTime(2024, 5, 6, 7, 8, 9),
        extension: 'sqlite',
      );

      expect(fileName, 'daily_manna-export-20240506-070809.sqlite');
    });

    test('builds json file names with zero-padded local timestamps', () {
      final fileName = buildDatabaseExportFileName(
        DateTime(2024, 11, 12, 13, 14, 15),
        extension: 'json',
      );

      expect(fileName, 'daily_manna-export-20241112-131415.json');
    });
  });
}
