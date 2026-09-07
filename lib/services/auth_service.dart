import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

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

class AuthService extends ChangeNotifier {
  AuthService({http.Client? client, AuthTokenStore? store, Uri? baseUrl})
    : _client = client ?? http.Client(),
      _store = store ?? const SecureAuthTokenStore(),
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
  Future<String?> tokenProvider() async => _token;

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
