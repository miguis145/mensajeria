import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app/core/api/messages_api.dart';

void main() {
  test('pide /messages con el token y devuelve la lista', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'http://servidor/messages');
      expect(request.headers['Authorization'], 'Bearer mi-token');
      return http.Response(
        jsonEncode({
          'messages': [
            {'id': 'm1', 'ciphertext': 'abc'},
            {'id': 'm2', 'ciphertext': 'def'},
          ],
        }),
        200,
      );
    });

    final api = MessagesApi(baseUrl: 'http://servidor', client: client);
    final messages = await api.listMessages('mi-token');

    expect(messages, hasLength(2));
    expect(messages.first['id'], 'm1');
  });

  test('lanza una excepción si el servidor responde con error', () async {
    final client = MockClient((_) async => http.Response('{"error":"x"}', 500));
    final api = MessagesApi(baseUrl: 'http://servidor', client: client);

    expect(api.listMessages('t'), throwsException);
  });
}
