// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ResultsTable extends Results with TableInfo<$ResultsTable, Result> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ResultType, int> type =
      GeneratedColumn<int>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<ResultType>($ResultsTable.$convertertype);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startChapterMeta = const VerificationMeta(
    'startChapter',
  );
  @override
  late final GeneratedColumn<int> startChapter = GeneratedColumn<int>(
    'start_chapter',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startVerseMeta = const VerificationMeta(
    'startVerse',
  );
  @override
  late final GeneratedColumn<int> startVerse = GeneratedColumn<int>(
    'start_verse',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endChapterMeta = const VerificationMeta(
    'endChapter',
  );
  @override
  late final GeneratedColumn<int> endChapter = GeneratedColumn<int>(
    'end_chapter',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endVerseMeta = const VerificationMeta(
    'endVerse',
  );
  @override
  late final GeneratedColumn<int> endVerse = GeneratedColumn<int>(
    'end_verse',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timestamp,
    type,
    bookId,
    startChapter,
    startVerse,
    endChapter,
    endVerse,
    score,
    attempts,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'results';
  @override
  VerificationContext validateIntegrity(
    Insertable<Result> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('start_chapter')) {
      context.handle(
        _startChapterMeta,
        startChapter.isAcceptableOrUnknown(
          data['start_chapter']!,
          _startChapterMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startChapterMeta);
    }
    if (data.containsKey('start_verse')) {
      context.handle(
        _startVerseMeta,
        startVerse.isAcceptableOrUnknown(data['start_verse']!, _startVerseMeta),
      );
    } else if (isInserting) {
      context.missing(_startVerseMeta);
    }
    if (data.containsKey('end_chapter')) {
      context.handle(
        _endChapterMeta,
        endChapter.isAcceptableOrUnknown(data['end_chapter']!, _endChapterMeta),
      );
    }
    if (data.containsKey('end_verse')) {
      context.handle(
        _endVerseMeta,
        endVerse.isAcceptableOrUnknown(data['end_verse']!, _endVerseMeta),
      );
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Result map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Result(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      type: $ResultsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}type'],
        )!,
      ),
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      startChapter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_chapter'],
      )!,
      startVerse: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_verse'],
      )!,
      endChapter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_chapter'],
      ),
      endVerse: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_verse'],
      ),
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $ResultsTable createAlias(String alias) {
    return $ResultsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ResultType, int, int> $convertertype =
      const EnumIndexConverter<ResultType>(ResultType.values);
}

class Result extends DataClass implements Insertable<Result> {
  final int id;
  final DateTime timestamp;
  final ResultType type;
  final String bookId;
  final int startChapter;
  final int startVerse;
  final int? endChapter;
  final int? endVerse;
  final double score;
  final int? attempts;
  final String? notes;
  const Result({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.bookId,
    required this.startChapter,
    required this.startVerse,
    this.endChapter,
    this.endVerse,
    required this.score,
    this.attempts,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    {
      map['type'] = Variable<int>($ResultsTable.$convertertype.toSql(type));
    }
    map['book_id'] = Variable<String>(bookId);
    map['start_chapter'] = Variable<int>(startChapter);
    map['start_verse'] = Variable<int>(startVerse);
    if (!nullToAbsent || endChapter != null) {
      map['end_chapter'] = Variable<int>(endChapter);
    }
    if (!nullToAbsent || endVerse != null) {
      map['end_verse'] = Variable<int>(endVerse);
    }
    map['score'] = Variable<double>(score);
    if (!nullToAbsent || attempts != null) {
      map['attempts'] = Variable<int>(attempts);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  ResultsCompanion toCompanion(bool nullToAbsent) {
    return ResultsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      type: Value(type),
      bookId: Value(bookId),
      startChapter: Value(startChapter),
      startVerse: Value(startVerse),
      endChapter: endChapter == null && nullToAbsent
          ? const Value.absent()
          : Value(endChapter),
      endVerse: endVerse == null && nullToAbsent
          ? const Value.absent()
          : Value(endVerse),
      score: Value(score),
      attempts: attempts == null && nullToAbsent
          ? const Value.absent()
          : Value(attempts),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory Result.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Result(
      id: serializer.fromJson<int>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      type: $ResultsTable.$convertertype.fromJson(
        serializer.fromJson<int>(json['type']),
      ),
      bookId: serializer.fromJson<String>(json['bookId']),
      startChapter: serializer.fromJson<int>(json['startChapter']),
      startVerse: serializer.fromJson<int>(json['startVerse']),
      endChapter: serializer.fromJson<int?>(json['endChapter']),
      endVerse: serializer.fromJson<int?>(json['endVerse']),
      score: serializer.fromJson<double>(json['score']),
      attempts: serializer.fromJson<int?>(json['attempts']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'type': serializer.toJson<int>($ResultsTable.$convertertype.toJson(type)),
      'bookId': serializer.toJson<String>(bookId),
      'startChapter': serializer.toJson<int>(startChapter),
      'startVerse': serializer.toJson<int>(startVerse),
      'endChapter': serializer.toJson<int?>(endChapter),
      'endVerse': serializer.toJson<int?>(endVerse),
      'score': serializer.toJson<double>(score),
      'attempts': serializer.toJson<int?>(attempts),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Result copyWith({
    int? id,
    DateTime? timestamp,
    ResultType? type,
    String? bookId,
    int? startChapter,
    int? startVerse,
    Value<int?> endChapter = const Value.absent(),
    Value<int?> endVerse = const Value.absent(),
    double? score,
    Value<int?> attempts = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => Result(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    type: type ?? this.type,
    bookId: bookId ?? this.bookId,
    startChapter: startChapter ?? this.startChapter,
    startVerse: startVerse ?? this.startVerse,
    endChapter: endChapter.present ? endChapter.value : this.endChapter,
    endVerse: endVerse.present ? endVerse.value : this.endVerse,
    score: score ?? this.score,
    attempts: attempts.present ? attempts.value : this.attempts,
    notes: notes.present ? notes.value : this.notes,
  );
  Result copyWithCompanion(ResultsCompanion data) {
    return Result(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      type: data.type.present ? data.type.value : this.type,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      startChapter: data.startChapter.present
          ? data.startChapter.value
          : this.startChapter,
      startVerse: data.startVerse.present
          ? data.startVerse.value
          : this.startVerse,
      endChapter: data.endChapter.present
          ? data.endChapter.value
          : this.endChapter,
      endVerse: data.endVerse.present ? data.endVerse.value : this.endVerse,
      score: data.score.present ? data.score.value : this.score,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Result(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('type: $type, ')
          ..write('bookId: $bookId, ')
          ..write('startChapter: $startChapter, ')
          ..write('startVerse: $startVerse, ')
          ..write('endChapter: $endChapter, ')
          ..write('endVerse: $endVerse, ')
          ..write('score: $score, ')
          ..write('attempts: $attempts, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    timestamp,
    type,
    bookId,
    startChapter,
    startVerse,
    endChapter,
    endVerse,
    score,
    attempts,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Result &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.type == this.type &&
          other.bookId == this.bookId &&
          other.startChapter == this.startChapter &&
          other.startVerse == this.startVerse &&
          other.endChapter == this.endChapter &&
          other.endVerse == this.endVerse &&
          other.score == this.score &&
          other.attempts == this.attempts &&
          other.notes == this.notes);
}

class ResultsCompanion extends UpdateCompanion<Result> {
  final Value<int> id;
  final Value<DateTime> timestamp;
  final Value<ResultType> type;
  final Value<String> bookId;
  final Value<int> startChapter;
  final Value<int> startVerse;
  final Value<int?> endChapter;
  final Value<int?> endVerse;
  final Value<double> score;
  final Value<int?> attempts;
  final Value<String?> notes;
  const ResultsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.type = const Value.absent(),
    this.bookId = const Value.absent(),
    this.startChapter = const Value.absent(),
    this.startVerse = const Value.absent(),
    this.endChapter = const Value.absent(),
    this.endVerse = const Value.absent(),
    this.score = const Value.absent(),
    this.attempts = const Value.absent(),
    this.notes = const Value.absent(),
  });
  ResultsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime timestamp,
    required ResultType type,
    required String bookId,
    required int startChapter,
    required int startVerse,
    this.endChapter = const Value.absent(),
    this.endVerse = const Value.absent(),
    required double score,
    this.attempts = const Value.absent(),
    this.notes = const Value.absent(),
  }) : timestamp = Value(timestamp),
       type = Value(type),
       bookId = Value(bookId),
       startChapter = Value(startChapter),
       startVerse = Value(startVerse),
       score = Value(score);
  static Insertable<Result> custom({
    Expression<int>? id,
    Expression<DateTime>? timestamp,
    Expression<int>? type,
    Expression<String>? bookId,
    Expression<int>? startChapter,
    Expression<int>? startVerse,
    Expression<int>? endChapter,
    Expression<int>? endVerse,
    Expression<double>? score,
    Expression<int>? attempts,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (type != null) 'type': type,
      if (bookId != null) 'book_id': bookId,
      if (startChapter != null) 'start_chapter': startChapter,
      if (startVerse != null) 'start_verse': startVerse,
      if (endChapter != null) 'end_chapter': endChapter,
      if (endVerse != null) 'end_verse': endVerse,
      if (score != null) 'score': score,
      if (attempts != null) 'attempts': attempts,
      if (notes != null) 'notes': notes,
    });
  }

  ResultsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? timestamp,
    Value<ResultType>? type,
    Value<String>? bookId,
    Value<int>? startChapter,
    Value<int>? startVerse,
    Value<int?>? endChapter,
    Value<int?>? endVerse,
    Value<double>? score,
    Value<int?>? attempts,
    Value<String?>? notes,
  }) {
    return ResultsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      bookId: bookId ?? this.bookId,
      startChapter: startChapter ?? this.startChapter,
      startVerse: startVerse ?? this.startVerse,
      endChapter: endChapter ?? this.endChapter,
      endVerse: endVerse ?? this.endVerse,
      score: score ?? this.score,
      attempts: attempts ?? this.attempts,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(
        $ResultsTable.$convertertype.toSql(type.value),
      );
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (startChapter.present) {
      map['start_chapter'] = Variable<int>(startChapter.value);
    }
    if (startVerse.present) {
      map['start_verse'] = Variable<int>(startVerse.value);
    }
    if (endChapter.present) {
      map['end_chapter'] = Variable<int>(endChapter.value);
    }
    if (endVerse.present) {
      map['end_verse'] = Variable<int>(endVerse.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResultsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('type: $type, ')
          ..write('bookId: $bookId, ')
          ..write('startChapter: $startChapter, ')
          ..write('startVerse: $startVerse, ')
          ..write('endChapter: $endChapter, ')
          ..write('endVerse: $endVerse, ')
          ..write('score: $score, ')
          ..write('attempts: $attempts, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ResultsTable results = $ResultsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [results];
}

typedef $$ResultsTableCreateCompanionBuilder =
    ResultsCompanion Function({
      Value<int> id,
      required DateTime timestamp,
      required ResultType type,
      required String bookId,
      required int startChapter,
      required int startVerse,
      Value<int?> endChapter,
      Value<int?> endVerse,
      required double score,
      Value<int?> attempts,
      Value<String?> notes,
    });
typedef $$ResultsTableUpdateCompanionBuilder =
    ResultsCompanion Function({
      Value<int> id,
      Value<DateTime> timestamp,
      Value<ResultType> type,
      Value<String> bookId,
      Value<int> startChapter,
      Value<int> startVerse,
      Value<int?> endChapter,
      Value<int?> endVerse,
      Value<double> score,
      Value<int?> attempts,
      Value<String?> notes,
    });

class $$ResultsTableFilterComposer
    extends Composer<_$AppDatabase, $ResultsTable> {
  $$ResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ResultType, ResultType, int> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startChapter => $composableBuilder(
    column: $table.startChapter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startVerse => $composableBuilder(
    column: $table.startVerse,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endChapter => $composableBuilder(
    column: $table.endChapter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endVerse => $composableBuilder(
    column: $table.endVerse,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $ResultsTable> {
  $$ResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startChapter => $composableBuilder(
    column: $table.startChapter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startVerse => $composableBuilder(
    column: $table.startVerse,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endChapter => $composableBuilder(
    column: $table.endChapter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endVerse => $composableBuilder(
    column: $table.endVerse,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ResultsTable> {
  $$ResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ResultType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get startChapter => $composableBuilder(
    column: $table.startChapter,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startVerse => $composableBuilder(
    column: $table.startVerse,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endChapter => $composableBuilder(
    column: $table.endChapter,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endVerse =>
      $composableBuilder(column: $table.endVerse, builder: (column) => column);

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$ResultsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ResultsTable,
          Result,
          $$ResultsTableFilterComposer,
          $$ResultsTableOrderingComposer,
          $$ResultsTableAnnotationComposer,
          $$ResultsTableCreateCompanionBuilder,
          $$ResultsTableUpdateCompanionBuilder,
          (Result, BaseReferences<_$AppDatabase, $ResultsTable, Result>),
          Result,
          PrefetchHooks Function()
        > {
  $$ResultsTableTableManager(_$AppDatabase db, $ResultsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<ResultType> type = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> startChapter = const Value.absent(),
                Value<int> startVerse = const Value.absent(),
                Value<int?> endChapter = const Value.absent(),
                Value<int?> endVerse = const Value.absent(),
                Value<double> score = const Value.absent(),
                Value<int?> attempts = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => ResultsCompanion(
                id: id,
                timestamp: timestamp,
                type: type,
                bookId: bookId,
                startChapter: startChapter,
                startVerse: startVerse,
                endChapter: endChapter,
                endVerse: endVerse,
                score: score,
                attempts: attempts,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime timestamp,
                required ResultType type,
                required String bookId,
                required int startChapter,
                required int startVerse,
                Value<int?> endChapter = const Value.absent(),
                Value<int?> endVerse = const Value.absent(),
                required double score,
                Value<int?> attempts = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => ResultsCompanion.insert(
                id: id,
                timestamp: timestamp,
                type: type,
                bookId: bookId,
                startChapter: startChapter,
                startVerse: startVerse,
                endChapter: endChapter,
                endVerse: endVerse,
                score: score,
                attempts: attempts,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ResultsTable,
      Result,
      $$ResultsTableFilterComposer,
      $$ResultsTableOrderingComposer,
      $$ResultsTableAnnotationComposer,
      $$ResultsTableCreateCompanionBuilder,
      $$ResultsTableUpdateCompanionBuilder,
      (Result, BaseReferences<_$AppDatabase, $ResultsTable, Result>),
      Result,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ResultsTableTableManager get results =>
      $$ResultsTableTableManager(_db, _db.results);
}
