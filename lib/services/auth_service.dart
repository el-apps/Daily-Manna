import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

abstract class AuthTokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureAuthTokenStore implements AuthTokenStore {
  const SecureAuthTokenStore();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Browser storage is used on web because the secure-storage web plugin's
/// WebCrypto key can become unavailable after a browser profile or origin
/// migration. The token is still scoped to this origin and is not used on
/// Android, where the platform secure store remains available.
class WebAuthTokenStore implements AuthTokenStore {
  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<String?> read(String key) async => (await _preferences).getString(key);

  @override
  Future<void> write(String key, String value) async {
    await (await _preferences).setString(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await (await _preferences).remove(key);
  }
}

class AuthService extends ChangeNotifier {
  AuthService({http.Client? client, AuthTokenStore? store, Uri? baseUrl})
    : _client = client ?? http.Client(),
      _store =
          store ??
          (kIsWeb ? WebAuthTokenStore() : const SecureAuthTokenStore()),
      baseUrl = baseUrl ?? _defaultBaseUrl;

  static const _tokenKey = 'auth_token';
  static const _emailKey = 'auth_email';
  static final Uri _defaultBaseUrl = Uri.parse(
    'https://dailymanna.kwila.cloud',
  );

  final http.Client _client;
  final AuthTokenStore _store;
  final Uri baseUrl;
  String? _token;
  String? _email;

  bool get isSignedIn => _token?.isNotEmpty == true;
  bool get isConfigured => baseUrl.hasScheme && baseUrl.host.isNotEmpty;
  String? get email => _email;
  Future<void>? _refreshing;

  /// PocketBase tokens expire (14 days by default), so the session is renewed
  /// well before expiry. An already-expired session is cleared so the user is
  /// asked to sign in again instead of syncing with a dead token forever.
  Future<String?> tokenProvider() async {
    final token = _token;
    if (token == null || token.isEmpty) return null;
    final expiry = tokenExpiry(token);
    if (expiry != null &&
        expiry.difference(DateTime.now()) < refreshThreshold) {
      await refresh();
    }
    return _token;
  }

  static const refreshThreshold = Duration(days: 7);

  /// Reads the `exp` claim of a JWT, or null if the token is not a JWT.
  static DateTime? tokenExpiry(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              )
              as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    } catch (_) {
      return null;
    }
  }

  /// Exchanges the current token for a fresh one. Rejection means the session
  /// is no longer valid, so it is signed out; network failures keep the token.
  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<void> _refresh() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final http.Response response;
    try {
      response = await _client
          .post(
            baseUrl.resolve('/api/collections/users/auth-refresh'),
            headers: {'Authorization': token},
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      return;
    }
    if (response.statusCode == 401 ||
        response.statusCode == 403 ||
        response.statusCode == 404) {
      await signOut();
      return;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) return;
    try {
      final fresh =
          (jsonDecode(response.body) as Map<String, dynamic>)['token'];
      if (fresh is String && fresh.isNotEmpty && _token == token) {
        _token = fresh;
        await _store.write(_tokenKey, fresh);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> init() async {
    _token = await _store.read(_tokenKey);
    _email = await _store.read(_emailKey);
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    if (!isConfigured) {
      throw const AuthException(
        'Account sync is not configured in this build.',
      );
    }
    final endpoint = baseUrl.resolve(
      '/api/collections/users/auth-with-password',
    );
    final response = await _client.post(
      endpoint,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identity': email.trim(), 'password': password}),
    );
    Map<String, dynamic> body = const {};
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}
    final token = body['token'];
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        token is! String ||
        token.isEmpty) {
      throw AuthException(
        body['message']?.toString() ??
            'Sign in failed (${response.statusCode}).',
      );
    }
    _token = token;
    _email = email.trim();
    await _store.write(_tokenKey, token);
    await _store.write(_emailKey, _email!);
    notifyListeners();
  }

  Future<void> signOut() async {
    _token = null;
    _email = null;
    await _store.delete(_tokenKey);
    await _store.delete(_emailKey);
    notifyListeners();
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
