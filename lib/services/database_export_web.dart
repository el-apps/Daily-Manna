import 'dart:convert';
import 'dart:typed_data';

import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/services/database_export_models.dart';
import 'package:share_plus/share_plus.dart';

class DatabaseExportService {
  final AppDatabase _db;

  DatabaseExportService(this._db);

  Future<DatabaseExportFile> exportDatabase() async {
    final fileName = buildDatabaseExportFileName(
      DateTime.now(),
      extension: 'json',
    );
    final payload = await _db.transaction(() async {
      final results = await _db.getAllResults();
      final notes = await _db.getStudyNotes();
      return jsonEncode({
        'exportedAt': DateTime.now().toIso8601String(),
        'tables': {
          'results': results.map(_resultToJson).toList(),
          'study_notes': notes.map(_studyNoteToJson).toList(),
        },
      });
    });

    return DatabaseExportFile(
      file: XFile.fromData(
        Uint8List.fromList(utf8.encode(payload)),
        name: fileName,
        mimeType: 'application/json',
      ),
      fileName: fileName,
    );
  }

  Map<String, dynamic> _resultToJson(Result result) => {
    'id': result.id,
    'timestamp': result.timestamp.toIso8601String(),
    'type': result.type.name,
    'bookId': result.bookId,
    'startChapter': result.startChapter,
    'startVerse': result.startVerse,
    'endChapter': result.endChapter,
    'endVerse': result.endVerse,
    'score': result.score,
    'attempts': result.attempts,
    'notes': result.notes,
    'studyNoteId': result.studyNoteId,
    'clientId': result.clientId,
    'updatedAt': result.updatedAt.toIso8601String(),
  };

  Map<String, dynamic> _studyNoteToJson(StudyNote note) => {
    'id': note.id,
    'clientId': note.clientId,
    'title': note.title,
    'notes': note.notes,
    'conceptMap': note.conceptMap,
    'passages': note.passages,
    'archived': note.archived,
    'createdAt': note.createdAt.toIso8601String(),
    'updatedAt': note.updatedAt.toIso8601String(),
  };
}
