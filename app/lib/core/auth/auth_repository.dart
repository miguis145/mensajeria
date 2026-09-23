import 'dart:convert';
import '../crypto/crypto_service.dart';
import '../api/auth_api.dart';
import '../storage/secure_storage_service.dart';

class AuthRepository {
  final CryptoService _crypto;
  final AuthApi _api;
  final SecureStorageService _storage;

  AuthRepository({
    required CryptoService crypto,
    required AuthApi api,
    required SecureStorageService storage,
  })  : _crypto = crypto,
        _api = api,
        _storage = storage;

  /// Registra un usuario nuevo: genera el par de claves EN EL DISPOSITIVO,
  /// sube solo la pública, y guarda la privada localmente cifrada.
  Future<void> register({
    required String username,
    required String password,
  }) async {
    final keyPair = _crypto.generateKeyPair();
    final publicKeyBase64 = base64Encode(keyPair.publicKey);

    final response = await _api.register(
      username: username,
      password: password,
      publicKeyBase64: publicKeyBase64,
    );

    await _storage.saveSession(
      privateKeyBytes: keyPair.secretKey.extractBytes(),
      token: response.token,
      userId: response.userId,
      username: username,
    );
  }

  /// Inicia sesión. Asume que la clave privada YA existe en este
  /// dispositivo (de un registro anterior) — si el usuario reinstaló
  /// la app o cambió de teléfono, la clave privada se pierde y no hay
  /// forma de recuperarla (por diseño: es la garantía de que el
  /// servidor nunca pudo tenerla).
  Future<void> login({
    required String username,
    required String password,
  }) async {
    final hasLocalKey = await _storage.getPrivateKey() != null;
    if (!hasLocalKey) {
      throw Exception(
        'No se encontró la clave privada en este dispositivo. '
        'Si reinstalaste la app o cambiaste de teléfono, no es posible '
        'recuperar mensajes anteriores — es una limitación de diseño '
        'del cifrado de extremo a extremo.',
      );
    }

    final response = await _api.login(username: username, password: password);

    final existingPrivateKey = await _storage.getPrivateKey();
    await _storage.saveSession(
      privateKeyBytes: existingPrivateKey!,
      token: response.token,
      userId: response.userId,
      username: username,
    );
  }

  Future<bool> hasStoredSession() => _storage.hasSession();

  Future<void> logout() => _storage.clear();
}