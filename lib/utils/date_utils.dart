extension DateOnlyExtension on DateTime {
  /// Returns a new DateTime with only the date component (time set to midnight).
  DateTime get dateOnly => DateTime(year, month, day);
}
