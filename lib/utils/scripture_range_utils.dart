import 'package:daily_manna/models/scripture_range_ref.dart';

/// Combines overlapping ranges, or ranges adjoining within a chapter.
List<ScriptureRangeRef> mergeAdjoiningRanges(List<ScriptureRangeRef> ranges) {
  final merged = <ScriptureRangeRef>[];
  for (final range in ranges) {
    var mergedRange = range;
    for (var index = 0; index < merged.length;) {
      final existing = merged[index];
      if (!_rangesAdjoin(existing, mergedRange)) {
        index++;
        continue;
      }

      mergedRange = _mergeRanges(existing, mergedRange);
      merged.removeAt(index);
    }
    merged.add(mergedRange);
  }
  return merged;
}

bool _rangesAdjoin(ScriptureRangeRef first, ScriptureRangeRef second) {
  if (first.bookId != second.bookId) return false;
  return first.overlaps(second) ||
      ((first.endChapter ?? first.chapter) == second.chapter &&
          (first.endVerse ?? first.startVerse) + 1 == second.startVerse) ||
      ((second.endChapter ?? second.chapter) == first.chapter &&
          (second.endVerse ?? second.startVerse) + 1 == first.startVerse);
}

ScriptureRangeRef _mergeRanges(
  ScriptureRangeRef first,
  ScriptureRangeRef second,
) {
  if (first.contains(second)) return first;
  if (second.contains(first)) return second;
  final firstStartsEarlier =
      first.chapter < second.chapter ||
      (first.chapter == second.chapter && first.startVerse < second.startVerse);
  final start = firstStartsEarlier ? first : second;
  final end = firstStartsEarlier ? second : first;
  final endChapter = end.endChapter ?? end.chapter;
  return ScriptureRangeRef(
    bookId: first.bookId,
    chapter: start.chapter,
    startVerse: start.startVerse,
    endChapter: endChapter == start.chapter ? null : endChapter,
    endVerse: end.endVerse ?? end.startVerse,
  );
}
