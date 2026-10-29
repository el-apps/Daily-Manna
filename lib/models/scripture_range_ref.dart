import 'package:freezed_annotation/freezed_annotation.dart';

part 'scripture_range_ref.freezed.dart';

/// An inclusive passage range within one book.
@freezed
abstract class ScriptureRangeRef with _$ScriptureRangeRef {
  const ScriptureRangeRef._();

  const factory ScriptureRangeRef({
    required String bookId,
    required int chapter,
    required int startVerse,
    int? endChapter,
    int? endVerse,
  }) = _ScriptureRangeRef;

  bool get complete => bookId.isNotEmpty && chapter > 0 && startVerse > 0;

  bool overlaps(ScriptureRangeRef query) =>
      bookId == query.bookId &&
      _compare(
            chapter,
            startVerse,
            query.endChapter ?? query.chapter,
            query.endVerse ?? query.startVerse,
          ) <=
          0 &&
      _compare(
            query.chapter,
            query.startVerse,
            endChapter ?? chapter,
            endVerse ?? startVerse,
          ) <=
          0;

  bool contains(ScriptureRangeRef query) =>
      bookId == query.bookId &&
      _compare(chapter, startVerse, query.chapter, query.startVerse) <= 0 &&
      _compare(
            endChapter ?? chapter,
            endVerse ?? startVerse,
            query.endChapter ?? query.chapter,
            query.endVerse ?? query.startVerse,
          ) >=
          0;
}

int _compare(int chapter, int verse, int otherChapter, int otherVerse) =>
    chapter == otherChapter
    ? verse.compareTo(otherVerse)
    : chapter.compareTo(otherChapter);
