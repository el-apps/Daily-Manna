import 'dart:async';
import 'dart:convert';

import 'package:daily_manna/services/database/database.dart';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

typedef AuthTokenProvider = Future<String?> Function();

class SyncResponse {
  const SyncResponse({required this.cursor, required this.changes});

  final int cursor;
  final List<Map<String, dynamic>> changes;
}

abstract class SyncTransport {
  Future<SyncResponse> exchange({
    required String clientId,
    required int cursor,
    required int baseCursor,
    required List<Map<String, dynamic>> changes,
    String? authToken,
  });
}

class HttpSyncTransport implements SyncTransport {
  HttpSyncTransport({Uri? endpoint, http.Client? client})
    : endpoint =
          endpoint ??
          Uri.parse(
            const String.fromEnvironment(
              'DAILY_MANNA_SYNC_URL',
              defaultValue: 'https://dailymanna.kwila.cloud/api/sync',
            ),
          ),
      _client = client ?? http.Client();

  final Uri endpoint;
  final http.Client _client;

  @override
  Future<SyncResponse> exchange({
    required String clientId,
    required int cursor,
    required int baseCursor,
    required List<Map<String, dynamic>> changes,
    String? authToken,
  }) async {
    final response = await _client
        .post(
          endpoint,
          headers: {
            'Content-Type': 'application/json',
            if (authToken != null && authToken.isNotEmpty)
              'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode({
            'clientId': clientId,
            'cursor': cursor,
            'baseCursor': baseCursor,
            'changes': changes,
          }),
        )
        .timeout(const Duration(seconds: 30));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SyncException(response.statusCode, body['error']?.toString());
    }
    return SyncResponse(
      cursor: (body['cursor'] as num).toInt(),
      changes: (body['changes'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
    );
  }
}

class SyncException implements Exception {
  const SyncException(this.statusCode, [this.message]);
  final int statusCode;
  final String? message;
  @override
  String toString() =>
      'SyncException($statusCode${message == null ? '' : ': $message'})';
}

/// Local-first result synchronization. Notification settings are deliberately
/// absent: they remain specific to each device.
class SyncService {
  SyncService(
    this._db, {
    SyncTransport? transport,
    AuthTokenProvider? authTokenProvider,
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _transport = transport ?? HttpSyncTransport(),
       _authTokenProvider = authTokenProvider,
       _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance;

  final AppDatabase _db;
  final SyncTransport _transport;
  final AuthTokenProvider? _authTokenProvider;
  final Future<SharedPreferences> Function() _preferencesProvider;
  static const _clientIdKey = 'sync_client_id';
  StreamSubscription<List<SyncOutboxData>>? _outboxSubscription;
  bool _syncing = false;
  bool _syncAgain = false;

  /// Starts syncing newly queued local changes for authenticated users.
  void startAutoSync() {
    _outboxSubscription ??= _db.watchPendingChanges().listen((pending) {
      if (pending.isNotEmpty) _requestSync();
    });
  }

  Future<void> dispose() async {
    await _outboxSubscription?.cancel();
    _outboxSubscription = null;
  }

  Future<void> _requestSync() async {
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncAgain = false;
        try {
          if (await _authTokenProvider?.call() != null) await sync();
        } catch (_) {
          // Keep the local outbox intact; a later write or manual retry can
          // attempt synchronization again.
        }
      } while (_syncAgain);
    } finally {
      _syncing = false;
    }
  }

  Future<String> getClientId() async {
    final preferences = await _preferencesProvider();
    final existing = preferences.getString(_clientIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = newClientId();
    await preferences.setString(_clientIdKey, created);
    return created;
  }

  /// Executes pull -> merge -> push -> final pull. Authentication is injected
  /// by the host app and may be omitted for endpoints that allow anonymous sync.
  Future<void> sync() async {
    final clientId = await getClientId();
    final token = await _authTokenProvider?.call();
    var cursor = int.tryParse(await _db.getSyncCursor() ?? '') ?? 0;

    final pulled = await _transport.exchange(
      clientId: clientId,
      cursor: cursor,
      baseCursor: cursor,
      changes: const [],
      authToken: token,
    );
    await _merge(pulled);
    cursor = pulled.cursor;

    final outbox = await _db.pendingChanges();
    final outgoing = <Map<String, dynamic>>[];
    for (final change in outbox) {
      final result = await _db.resultByClientId(change.entityId);
      if (result != null) outgoing.add(_encodeResult(result));
    }
    if (outgoing.isNotEmpty) {
      final pushed = await _transport.exchange(
        clientId: clientId,
        cursor: cursor,
        baseCursor: cursor,
        changes: outgoing,
        authToken: token,
      );
      await _merge(pushed);
      await _db.acknowledgeChanges(outbox.map((change) => change.id));
      cursor = pushed.cursor;
    }

    final finalPull = await _transport.exchange(
      clientId: clientId,
      cursor: cursor,
      baseCursor: cursor,
      changes: const [],
      authToken: token,
    );
    await _merge(finalPull);
  }

  Future<void> _merge(SyncResponse response) => _db.transaction(() async {
    for (final change in response.changes) {
      if (change['type'] != 'result') continue;
      final id = change['id'] as String;
      if (await _db.hasPendingChange(id)) continue;
      if (change['deleted'] == true) {
        await _db.deleteRemoteResult(id);
      } else {
        await _db.mergeRemoteResult(_decodeResult(id, change['data'] as Map));
      }
    }
    await _db.setSyncCursor(response.cursor.toString());
  });

  Map<String, dynamic> _encodeResult(Result result) => {
    'type': 'result',
    'id': result.clientId,
    'data': {
      'timestamp': result.timestamp.toUtc().toIso8601String(),
      'resultType': result.type.name,
      'bookId': result.bookId,
      'startChapter': result.startChapter,
      'startVerse': result.startVerse,
      'endChapter': result.endChapter,
      'endVerse': result.endVerse,
      'score': result.score,
      'attempts': result.attempts,
      'notes': result.notes,
      'updatedAt': result.updatedAt.toUtc().toIso8601String(),
    },
  };

  ResultsCompanion _decodeResult(String id, Map<dynamic, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);
    return ResultsCompanion.insert(
      timestamp: DateTime.parse(data['timestamp'] as String),
      type: ResultType.values.byName(data['resultType'] as String),
      bookId: data['bookId'] as String,
      startChapter: (data['startChapter'] as num).toInt(),
      startVerse: (data['startVerse'] as num).toInt(),
      endChapter: Value((data['endChapter'] as num?)?.toInt()),
      endVerse: Value((data['endVerse'] as num?)?.toInt()),
      score: (data['score'] as num).toDouble(),
      attempts: Value((data['attempts'] as num?)?.toInt()),
      notes: Value(data['notes'] as String?),
      clientId: Value(id),
      updatedAt: Value(DateTime.parse(data['updatedAt'] as String)),
    );
  }
}
