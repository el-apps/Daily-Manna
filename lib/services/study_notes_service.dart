import 'dart:convert';

import 'package:daily_manna/models/concept_map.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/services/database/database.dart';
import 'package:drift/drift.dart';

class StudyNotesService {
  StudyNotesService(this._db);

  final AppDatabase _db;
  Future<void> Function()? onLocalChange;

  Stream<List<StudyNote>> watchNotes() => _db.watchStudyNotes();

  Future<StudyNote?> getNote(int id) => _db.studyNoteById(id);

  Future<StudyNote?> getNoteByClientId(String id) =>
      _db.studyNoteByClientId(id);

  Future<StudyNote> createNote({
    required String title,
    required ScriptureRangeRef passage,
  }) async {
    final id = await _db.insertStudyNote(
      StudyNotesCompanion.insert(
        title: title.trim(),
        passages: _encodePassages([passage]),
        conceptMap: Value(
          const ConceptMapDocument().addPassage(passage).toMermaid(),
        ),
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await onLocalChange?.call();
    return (await _db.studyNoteById(id))!;
  }

  Future<void> updateNotes(int id, String? notes) async {
    await _db.updateStudyNote(id, notes: Value(notes));
    await onLocalChange?.call();
  }

  Future<void> updateConceptMap(int id, String conceptMap) async {
    await _db.updateStudyNote(id, conceptMap: conceptMap);
    await onLocalChange?.call();
  }

  Future<void> addPassage(
    int id,
    ScriptureRangeRef passage, {
    ConceptMapDocument? conceptMap,
  }) async {
    final note = await _db.studyNoteById(id);
    if (note == null) return;
    final passages = _decodePassages(note.passages);
    final added = !passages.contains(passage);
    if (added) passages.add(passage);
    final document =
        conceptMap ?? ConceptMapDocument.fromMermaid(note.conceptMap ?? '');
    final updatedMap = document.addPassage(passage).toMermaid();
    if (added || updatedMap != note.conceptMap) {
      await _db.updateStudyNote(
        id,
        passages: _encodePassages(passages),
        conceptMap: updatedMap,
      );
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
}
