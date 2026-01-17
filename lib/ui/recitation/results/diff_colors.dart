import 'package:flutter/material.dart';
import 'package:word_tools/word_tools.dart';

extension DiffStatusColors on DiffStatus {
  MaterialColor get primaryColor => switch (this) {
    DiffStatus.correct => Colors.green,
    DiffStatus.missing => Colors.red,
    DiffStatus.extra => Colors.yellow,
  };

  (Color bgColor, Color textColor) get colors =>
      (primaryColor.withValues(alpha: 0.25), primaryColor.shade100);
}
