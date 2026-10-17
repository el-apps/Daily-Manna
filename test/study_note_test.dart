import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScriptureRangeRef.overlaps', () {
    const query = ScriptureRangeRef(
      bookId: 'Jas',
      chapter: 1,
      startVerse: 9,
      endVerse: 11,
    );

    test('matches any shared verse', () {
      expect(
        const ScriptureRangeRef(
          bookId: 'Jas',
          chapter: 1,
          startVerse: 10,
          endVerse: 12,
        ).overlaps(query),
        isTrue,
      );
      expect(
        const ScriptureRangeRef(
          bookId: 'Jas',
          chapter: 1,
          startVerse: 1,
          endVerse: 8,
        ).overlaps(query),
        isFalse,
      );
    });

    test('does not match a different book or chapter', () {
      expect(
        const ScriptureRangeRef(
          bookId: 'Jas',
          chapter: 2,
          startVerse: 9,
        ).overlaps(query),
        isFalse,
      );
      expect(
        const ScriptureRangeRef(
          bookId: 'Pet1',
          chapter: 1,
          startVerse: 9,
          endVerse: 11,
        ).overlaps(query),
        isFalse,
      );
    });
  });
}
