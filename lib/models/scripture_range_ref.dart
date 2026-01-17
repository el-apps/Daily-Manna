import 'package:freezed_annotation/freezed_annotation.dart';

part 'scripture_range_ref.freezed.dart';

@freezed
abstract class ScriptureRangeRef with _$ScriptureRangeRef {
  const ScriptureRangeRef._();

  const factory ScriptureRangeRef({
    required String bookId,
    required int startChapter,
    required int startVerse,
    int? endChapter,
    int? endVerse,
  }) = _ScriptureRangeRef;

  bool get complete => bookId.isNotEmpty && startChapter > 0 && startVerse > 0;
}
