import 'dart:convert';

import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/services/database/database.dart';

class StudyNotesService {
  StudyNotesService(this._db);

  final AppDatabase _db;
  Future<void> Function()? onLocalChange;

  Stream<List<StudyNote>> watchNotes() => _db.watchStudyNotes();

  Future<StudyNote?> getNote(int id) => _db.studyNoteById(id);

  Future<StudyNote> createNote({
    required String title,
    required ScriptureRangeRef passage,
  }) async {
    final id = await _db.insertStudyNote(
      StudyNotesCompanion.insert(
        title: title.trim(),
        passages: _encodePassages([passage]),
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await onLocalChange?.call();
    return (await _db.studyNoteById(id))!;
  }

  Future<void> updateNotes(int id, String? notes) async {
    await _db.updateStudyNote(id, notes: notes);
    await onLocalChange?.call();
  }

  Future<void> addPassage(int id, ScriptureRangeRef passage) async {
    final note = await _db.studyNoteById(id);
    if (note == null) return;
    final passages = _decodePassages(note.passages);
    final newPassage = passage;
    if (!passages.any((existing) => _samePassage(existing, newPassage))) {
      passages.add(newPassage);
      await _db.updateStudyNote(id, passages: _encodePassages(passages));
      await onLocalChange?.call();
    }
  }

  Future<List<StudyNote>> findByPassage(ScriptureRangeRef passage) async {
    final notes = await _db.getStudyNotes();
    return notes
        .where(
          (note) => _decodePassages(
            note.passages,
          ).any((reference) => reference.overlaps(passage)),
        )
        .toList();
  }

  List<ScriptureRangeRef> passagesFor(StudyNote note) =>
      _decodePassages(note.passages);

  static String _encodePassages(List<ScriptureRangeRef> passages) => jsonEncode(
    passages
        .map(
          (passage) => {
            'bookId': passage.bookId,
            'chapter': passage.chapter,
            'startVerse': passage.startVerse,
            'endVerse': passage.endVerse,
          },
        )
        .toList(),
  );

  static List<ScriptureRangeRef> _decodePassages(String value) {
    try {
      final raw = jsonDecode(value) as List;
      return raw.map((item) {
        final json = Map<String, dynamic>.from(item as Map);
        return ScriptureRangeRef(
          bookId: json['bookId'] as String,
          chapter: (json['chapter'] as num).toInt(),
          startVerse: (json['startVerse'] as num).toInt(),
          endVerse: (json['endVerse'] as num?)?.toInt(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static bool _samePassage(ScriptureRangeRef a, ScriptureRangeRef b) =>
      a.bookId == b.bookId &&
      a.chapter == b.chapter &&
      a.startVerse == b.startVerse &&
      a.endVerse == b.endVerse;
}
