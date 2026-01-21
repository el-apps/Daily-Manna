import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BibleService.getRangeRefName', () {
    late BibleService bibleService;

    setUp(() {
      bibleService = _createTestBibleService();
    });

    test('shows single verse when no end verse', () {
      final ref = ScriptureRangeRef(
        bookId: 'gen',
        chapter: 1,
        startVerse: 1,
      );

      expect(bibleService.getRangeRefName(ref), 'Genesis 1:1');
    });

    test('shows verse range in same chapter', () {
      final ref = ScriptureRangeRef(
        bookId: 'john',
        chapter: 3,
        startVerse: 16,
        endVerse: 18,
      );

      expect(bibleService.getRangeRefName(ref), 'John 3:16-18');
    });

    test('shows single verse when endVerse equals startVerse', () {
      final ref = ScriptureRangeRef(
        bookId: 'john',
        chapter: 3,
        startVerse: 16,
        endVerse: 16,
      );

      expect(bibleService.getRangeRefName(ref), 'John 3:16');
    });
  });
}

class _MockBook {
  final String id;
  final String title;

  _MockBook({required this.id, required this.title});
}

BibleService _createTestBibleService() {
  final mockBooks = {
    'gen': _MockBook(id: 'gen', title: 'Genesis'),
    'john': _MockBook(id: 'john', title: 'John'),
  };

  return _TestBibleService(mockBooks);
}

class _TestBibleService extends BibleService {
  final Map<String, _MockBook> mockBooks;

  _TestBibleService(this.mockBooks);

  @override
  String getRangeRefName(ScriptureRangeRef ref) {
    final bookTitle = mockBooks[ref.bookId]?.title ?? 'Unknown';

    if (ref.endVerse == null || ref.endVerse == ref.startVerse) {
      return '$bookTitle ${ref.chapter}:${ref.startVerse}';
    }
    return '$bookTitle ${ref.chapter}:${ref.startVerse}-${ref.endVerse}';
  }
}
