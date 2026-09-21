import 'package:daily_manna/models/scripture_range_ref.dart';

/// A passage reference stored on a long-lived study note.
class StudyNotePassage {
  const StudyNotePassage({
    required this.bookId,
    required this.chapter,
    required this.startVerse,
    this.endVerse,
  });

  final String bookId;
  final int chapter;
  final int startVerse;
  final int? endVerse;

  ScriptureRangeRef get ref => ScriptureRangeRef(
    bookId: bookId,
    chapter: chapter,
    startVerse: startVerse,
    endVerse: endVerse,
  );

  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'chapter': chapter,
    'startVerse': startVerse,
    'endVerse': endVerse,
  };

  factory StudyNotePassage.fromJson(Map<String, dynamic> json) =>
      StudyNotePassage(
        bookId: json['bookId'] as String,
        chapter: (json['chapter'] as num).toInt(),
        startVerse: (json['startVerse'] as num).toInt(),
        endVerse: (json['endVerse'] as num?)?.toInt(),
      );

  bool overlaps(ScriptureRangeRef query) {
    if (bookId != query.bookId || chapter != query.chapter) return false;
    final thisEnd = endVerse ?? startVerse;
    final queryEnd = query.endVerse ?? query.startVerse;
    return startVerse <= queryEnd && thisEnd >= query.startVerse;
  }
}
