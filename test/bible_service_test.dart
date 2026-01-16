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
        startChapter: 1,
        startVerse: 1,
      );

      expect(bibleService.getRangeRefName(ref), 'Genesis 1:1');
    });

    test('shows verse range in same chapter', () {
      final ref = ScriptureRangeRef(
        bookId: 'john',
        startChapter: 3,
        startVerse: 16,
        endChapter: 3,
        endVerse: 18,
      );

      expect(bibleService.getRangeRefName(ref), 'John 3:16-18');
    });

    test('shows verse range across chapters', () {
      final ref = ScriptureRangeRef(
        bookId: 'john',
        startChapter: 3,
        startVerse: 16,
        endChapter: 4,
        endVerse: 5,
      );

      expect(bibleService.getRangeRefName(ref), 'John 3:16-4:5');
    });

    test('shows single verse with end chapter only', () {
      final ref = ScriptureRangeRef(
        bookId: 'john',
        startChapter: 3,
        startVerse: 16,
        endChapter: 3,
      );

      expect(bibleService.getRangeRefName(ref), 'John 3:16');
    });
  });
}

class _MockBook {
  final String id;
  final String title;

  _MockBook({
    required this.id,
    required this.title,
  });
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

    if (ref.endChapter == null || ref.endVerse == null) {
      return '$bookTitle ${ref.startChapter}:${ref.startVerse}';
    }
    if (ref.endChapter == ref.startChapter) {
      return '$bookTitle ${ref.startChapter}:${ref.startVerse}-${ref.endVerse}';
    }
    return '$bookTitle ${ref.startChapter}:${ref.startVerse}-${ref.endChapter}:${ref.endVerse}';
  }
}
