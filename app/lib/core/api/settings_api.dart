import 'dart:convert';

import 'package:http/http.dart' as http;

class SettingsApi {
  final String baseUrl;
  final http.Client _client;

  SettingsApi({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  Future<int> getDefaultExpiry(String token) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/settings'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) {
      throw Exception('No se pudo cargar la configuración');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['defaultExpirySeconds'] as int;
  }

  Future<int> updateDefaultExpiry(String token, int seconds) async {
    final res = await _client.patch(
      Uri.parse('$baseUrl/settings'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'defaultExpirySeconds': seconds}),
    );
    if (res.statusCode != 200) {
      throw Exception('No se pudo actualizar la configuración');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['defaultExpirySeconds'] as int;
  }
}
