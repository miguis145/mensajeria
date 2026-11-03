import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthApiException implements Exception {
  final String message;
  final int statusCode;
  AuthApiException(this.message, this.statusCode);

  @override
  String toString() => 'AuthApiException($statusCode): $message';
}

class AuthResponse {
  final String token;
  final String userId;
  AuthResponse({required this.token, required this.userId});
}

class AuthApi {
  final String baseUrl;
  final http.Client _client;

  AuthApi({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  Future<AuthResponse> register({
    required String username,
    required String password,
    required String publicKeyBase64,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'publicKey': publicKeyBase64,
      }),
    );
    return _handleAuthResponse(res);
  }

  Future<AuthResponse> login({
    required String username,
    required String password,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    return _handleAuthResponse(res);
  }

  AuthResponse _handleAuthResponse(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode == 201 || res.statusCode == 200) {
      return AuthResponse(token: body['token'], userId: body['userId']);
    }

    final message = body['error'] ?? 'Error desconocido';
    throw AuthApiException(message, res.statusCode);
  }
}
