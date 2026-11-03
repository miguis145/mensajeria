import 'dart:convert';

import 'package:http/http.dart' as http;

/// Pide al servidor los mensajes pendientes de este usuario (los que llegaron
/// mientras la app estaba cerrada o sin red) y que aún no han caducado.
class MessagesApi {
  final String baseUrl;
  final http.Client _client;

  MessagesApi({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  /// Devuelve los mensajes tal como los manda el servidor (cifrados, en base64).
  /// Descifrarlos es trabajo del ChatController, que tiene la clave privada.
  Future<List<Map<String, dynamic>>> listMessages(String token) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/messages'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('No se pudieron cargar los mensajes pendientes');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['messages'] as List;
    return list.map((m) => m as Map<String, dynamic>).toList();
  }
}
