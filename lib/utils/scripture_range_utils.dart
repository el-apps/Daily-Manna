import 'package:daily_manna/models/scripture_range_ref.dart';

/// Combines overlapping or directly adjoining ranges in the same chapter.
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
  if (first.bookId != second.bookId || first.chapter != second.chapter) {
    return false;
  }
  final firstEnd = first.endVerse ?? first.startVerse;
  final secondEnd = second.endVerse ?? second.startVerse;
  return second.startVerse <= firstEnd + 1 && first.startVerse <= secondEnd + 1;
}

ScriptureRangeRef _mergeRanges(
  ScriptureRangeRef first,
  ScriptureRangeRef second,
) {
  final firstEnd = first.endVerse ?? first.startVerse;
  final secondEnd = second.endVerse ?? second.startVerse;
  return ScriptureRangeRef(
    bookId: first.bookId,
    chapter: first.chapter,
    startVerse: first.startVerse < second.startVerse
        ? first.startVerse
        : second.startVerse,
    endVerse: firstEnd > secondEnd ? firstEnd : secondEnd,
  );
}
