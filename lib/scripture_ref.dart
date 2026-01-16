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
  if (chapterNumber == null) {
    return bookTitle ?? 'Unknown';
  }
  if (verseNumber == null) {
    return '$bookTitle $chapterNumber';
  }
  return '$bookTitle $chapterNumber:$verseNumber';
}
