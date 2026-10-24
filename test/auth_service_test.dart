import 'dart:convert';

import 'package:daily_manna/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryTokenStore implements AuthTokenStore {
  final values = <String, String>{};
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  test('PocketBase sign in persists and restores the session', () async {
    final store = MemoryTokenStore();
    final client = MockClient((request) async {
      expect(request.url.path, '/api/collections/users/auth-with-password');
      expect(jsonDecode(request.body), {
        'identity': 'person@example.com',
        'password': 'secret',
      });
      return http.Response(jsonEncode({'token': 'jwt-token'}), 200);
    });
    final auth = AuthService(
      client: client,
      store: store,
      baseUrl: Uri.parse('https://accounts.example.com'),
    );

    await auth.signIn(' person@example.com ', 'secret');
    expect(auth.isSignedIn, isTrue);
    expect(await auth.tokenProvider(), 'jwt-token');

    final restored = AuthService(client: client, store: store);
    await restored.init();
    expect(restored.isSignedIn, isTrue);
    expect(restored.email, 'person@example.com');

    await restored.signOut();
    expect(restored.isSignedIn, isFalse);
    expect(store.values, isEmpty);
  });

  test('failed sign in does not persist a session', () async {
    final store = MemoryTokenStore();
    final auth = AuthService(
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode({'message': 'Invalid login'}), 400),
      ),
      store: store,
      baseUrl: Uri.parse('https://accounts.example.com'),
    );

    await expectLater(
      auth.signIn('a@b.com', 'wrong'),
      throwsA(isA<AuthException>()),
    );
    expect(auth.isSignedIn, isFalse);
    expect(store.values, isEmpty);
  });

  String jwt(DateTime expiry) {
    String part(Map<String, dynamic> value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    return '${part({'alg': 'HS256'})}.'
        '${part({'exp': expiry.millisecondsSinceEpoch ~/ 1000})}.sig';
  }

  test('near-expiry token is refreshed before use', () async {
    final store = MemoryTokenStore();
    final old = jwt(DateTime.now().add(const Duration(days: 1)));
    final fresh = jwt(DateTime.now().add(const Duration(days: 14)));
    store.values['auth_token'] = old;
    final auth = AuthService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/collections/users/auth-refresh');
        expect(request.headers['Authorization'], old);
        return http.Response(jsonEncode({'token': fresh}), 200);
      }),
      store: store,
      baseUrl: Uri.parse('https://accounts.example.com'),
    );
    await auth.init();
    expect(await auth.tokenProvider(), fresh);
    expect(store.values['auth_token'], fresh);
  });

  test('expired token that cannot be refreshed signs out', () async {
    final store = MemoryTokenStore();
    store.values['auth_token'] = jwt(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    store.values['auth_email'] = 'a@b.com';
    final auth = AuthService(
      client: MockClient(
        (_) async => http.Response('{"message":"Unauthorized"}', 401),
      ),
      store: store,
      baseUrl: Uri.parse('https://accounts.example.com'),
    );
    await auth.init();
    expect(await auth.tokenProvider(), isNull);
    expect(auth.isSignedIn, isFalse);
    expect(store.values, isEmpty);
  });

  test('network failure during refresh keeps the session', () async {
    final store = MemoryTokenStore();
    final token = jwt(DateTime.now().add(const Duration(days: 1)));
    store.values['auth_token'] = token;
    final auth = AuthService(
      client: MockClient((_) async => throw Exception('offline')),
      store: store,
      baseUrl: Uri.parse('https://accounts.example.com'),
    );
    await auth.init();
    expect(await auth.tokenProvider(), token);
  });
}
