import 'package:daily_manna/models/result_item.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'result_section.freezed.dart';

@freezed
abstract class ResultSection with _$ResultSection {
  const factory ResultSection({
    required String title,
    required List<ResultItem> items,
  }) = _ResultSection;
}
