// test/auth_api_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app/core/api/auth_api.dart';

void main() {
  group('AuthApi.register', () {
    test('devuelve token y userId en un registro exitoso', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/auth/register');
        final body = jsonDecode(request.body);
        expect(body['username'], 'fr4nk');

        return http.Response(
          jsonEncode({'token': 'token-falso', 'userId': 'user-1'}),
          201,
        );
      });

      final api = AuthApi(baseUrl: 'http://test.local', client: mockClient);
      final result = await api.register(
        username: 'fr4nk',
        password: 'pass123',
        publicKeyBase64: 'clave-falsa',
      );

      expect(result.token, 'token-falso');
      expect(result.userId, 'user-1');
    });

    test('lanza AuthApiException si el username ya existe (409)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Ese username ya está en uso'}),
          409,
        );
      });

      final api = AuthApi(baseUrl: 'http://test.local', client: mockClient);

      expect(
        () => api.register(
          username: 'fr4nk',
          password: 'pass123',
          publicKeyBase64: 'clave-falsa',
        ),
        throwsA(isA<AuthApiException>()),
      );
    });
  });

  group('AuthApi.login', () {
    test('rechaza credenciales inválidas (401)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Credenciales inválidas'}),
          401,
        );
      });

      final api = AuthApi(baseUrl: 'http://test.local', client: mockClient);

      expect(
        () => api.login(username: 'fr4nk', password: 'mala'),
        throwsA(isA<AuthApiException>()),
      );
    });
  });
}