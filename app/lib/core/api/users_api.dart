import 'dart:convert';

import 'package:http/http.dart' as http;

class FamilyUser {
  final String id;
  final String username;
  final String publicKeyBase64;

  FamilyUser({
    required this.id,
    required this.username,
    required this.publicKeyBase64,
  });

  factory FamilyUser.fromJson(Map<String, dynamic> json) => FamilyUser(
    id: json['id'],
    username: json['username'],
    publicKeyBase64: json['publicKey'],
  );
}

class UsersApi {
  final String baseUrl;
  final http.Client _client;

  UsersApi({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  Future<List<FamilyUser>> listUsers(String token) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/users'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('No se pudo cargar la lista de usuarios');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final usersJson = body['users'] as List;
    return usersJson.map((u) => FamilyUser.fromJson(u)).toList();
  }
}
