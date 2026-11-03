import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _kPrivateKey = 'private_key';
  static const _kToken = 'auth_token';
  static const _kUserId = 'user_id';
  static const _kUsername = 'username';

  Future<void> saveSession({
    required Uint8List privateKeyBytes,
    required String token,
    required String userId,
    required String username,
  }) async {
    await _storage.write(
      key: _kPrivateKey,
      value: base64Encode(privateKeyBytes),
    );
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kUserId, value: userId);
    await _storage.write(key: _kUsername, value: username);
  }

  Future<Uint8List?> getPrivateKey() async {
    final encoded = await _storage.read(key: _kPrivateKey);
    if (encoded == null) return null;
    return base64Decode(encoded);
  }

  Future<String?> getToken() async => _storage.read(key: _kToken);
  Future<String?> getUserId() async => _storage.read(key: _kUserId);
  Future<String?> getUsername() async => _storage.read(key: _kUsername);

  /// true si hay una sesión guardada completa (token + clave privada).
  Future<bool> hasSession() async {
    final token = await getToken();
    final privateKey = await getPrivateKey();
    return token != null && privateKey != null;
  }

  Future<void> clear() async {
    await _storage.delete(key: _kPrivateKey);
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kUsername);
  }
}
