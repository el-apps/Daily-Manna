import 'package:freezed_annotation/freezed_annotation.dart';

part 'scripture_range_ref.freezed.dart';

/// A reference to a passage range within a single chapter.
@freezed
abstract class ScriptureRangeRef with _$ScriptureRangeRef {
  const ScriptureRangeRef._();

  const factory ScriptureRangeRef({
    required String bookId,
    required int chapter,
    required int startVerse,
    int? endVerse,
  }) = _ScriptureRangeRef;

  bool get complete => bookId.isNotEmpty && chapter > 0 && startVerse > 0;
}
