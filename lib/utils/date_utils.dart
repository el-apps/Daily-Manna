extension DateOnlyExtension on DateTime {
  /// Returns a new DateTime with only the date component (time set to midnight).
  DateTime get dateOnly => DateTime(year, month, day);

  /// Returns the local calendar day for this timestamp.
  DateTime get localDateOnly => toLocal().dateOnly;
}

Set<DateTime> normalizeActivityDays(Iterable<DateTime> timestamps) =>
    timestamps.map((timestamp) => timestamp.localDateOnly).toSet();
