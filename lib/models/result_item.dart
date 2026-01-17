import 'package:freezed_annotation/freezed_annotation.dart';

part 'result_item.freezed.dart';

@freezed
abstract class ResultItem with _$ResultItem {
  const factory ResultItem({required String score, required String reference}) =
      _ResultItem;
}
