import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

enum ResultType { memorization, recitation }

class Results extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get timestamp => dateTime()();
  IntColumn get type => intEnum<ResultType>()();
  TextColumn get bookId => text()();
  IntColumn get startChapter => integer()();
  IntColumn get startVerse => integer()();
  IntColumn get endChapter => integer().nullable()();
  IntColumn get endVerse => integer().nullable()();
  RealColumn get score => real()();
  IntColumn get attempts => integer().nullable()();
}

@DriftDatabase(tables: [Results])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing with an in-memory database.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() => driftDatabase(name: 'daily_manna');

  // Insert a new result
  Future<int> insertResult(ResultsCompanion result) =>
      into(results).insert(result);

  // Get all results, newest first
  Future<List<Result>> getAllResults() =>
      (select(results)..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).get();

  // Watch all results (reactive stream)
  Stream<List<Result>> watchAllResults() => (select(
    results,
  )..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).watch();

  // Get results for a specific verse
  Future<List<Result>> getResultsForVerse(
    String bookId,
    int chapter,
    int verse,
  ) =>
      (select(results)..where(
            (t) =>
                t.bookId.equals(bookId) &
                t.startChapter.equals(chapter) &
                t.startVerse.equals(verse),
          ))
          .get();

  // Get unique verses that have been practiced
  Future<List<({String bookId, int chapter, int verse})>>
  getUniqueVersesPracticed() async {
    final query = selectOnly(results, distinct: true)
      ..addColumns([results.bookId, results.startChapter, results.startVerse]);
    final rows = await query.get();
    return rows
        .map(
          (row) => (
            bookId: row.read(results.bookId)!,
            chapter: row.read(results.startChapter)!,
            verse: row.read(results.startVerse)!,
          ),
        )
        .toList();
  }

  // Get results from today (since midnight)
  Future<List<Result>> getTodayResults() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    return (select(results)
          ..where((t) => t.timestamp.isBiggerOrEqualValue(midnight))
          ..orderBy([
            (t) => OrderingTerm.desc(t.timestamp),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .get();
  }
}
