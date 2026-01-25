import 'package:freezed_annotation/freezed_annotation.dart';

part 'result_item.freezed.dart';

@freezed
abstract class ResultItem with _$ResultItem {
  const factory ResultItem({
    required double score,
    required String reference,
    @Default(1) int attempts,
    String? notes,
  }) = _ResultItem;
}
