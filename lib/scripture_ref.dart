import 'package:freezed_annotation/freezed_annotation.dart';

part 'scripture_ref.freezed.dart';

@freezed
abstract class ScriptureRef with _$ScriptureRef {
  const ScriptureRef._();

  const factory ScriptureRef({
    String? bookId,
    int? chapterNumber,
    int? verseNumber,
  }) = _ScriptureRef;

  bool get complete =>
      bookId != null && chapterNumber != null && verseNumber != null;

  @override
  toString() => refString(bookId, chapterNumber, verseNumber);
}

String refString(String? bookTitle, int? chapterNumber, int? verseNumber) {
  final book = bookTitle ?? 'Unknown';
  if (chapterNumber == null) {
    return book;
  }
  if (verseNumber == null) {
    return '$book $chapterNumber';
  }
  return '$book $chapterNumber:$verseNumber';
}
