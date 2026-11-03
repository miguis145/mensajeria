import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs.dart';

class EncryptedPayload {
  final Uint8List ciphertext;
  final Uint8List nonce;

  EncryptedPayload({required this.ciphertext, required this.nonce});
}

class CryptoService {
  final Sodium _sodium;

  CryptoService._(this._sodium);

  /// Inicializa el motor de cifrado. Se llama UNA SOLA VEZ al arrancar la app
  /// (equivalente a `await sodium.ready` en la versión de Node).
  static Future<CryptoService> init() async {
    final sodium = await SodiumInit.init();
    return CryptoService._(sodium);
  }

  /// Genera un par de claves nuevo (equivalente a keys.ts del backend).
  KeyPair generateKeyPair() => _sodium.crypto.box.keyPair();

  /// Cifra un mensaje para un receptor específico.
  EncryptedPayload encryptMessage({
    required Uint8List message,
    required Uint8List receiverPublicKey,
    required SecureKey senderPrivateKey,
  }) {
    final nonce = _sodium.randombytes.buf(_sodium.crypto.box.nonceBytes);

    final ciphertext = _sodium.crypto.box.easy(
      message: message,
      nonce: nonce,
      publicKey: receiverPublicKey,
      secretKey: senderPrivateKey,
    );

    return EncryptedPayload(ciphertext: ciphertext, nonce: nonce);
  }

  /// Descifra un mensaje recibido.
  /// A diferencia de la versión JS (que devolvía `false` en error),
  /// aquí lanza SodiumException directamente si algo falla.
  Uint8List decryptMessage({
    required Uint8List ciphertext,
    required Uint8List nonce,
    required Uint8List senderPublicKey,
    required SecureKey receiverPrivateKey,
  }) {
    return _sodium.crypto.box.openEasy(
      cipherText: ciphertext,
      nonce: nonce,
      publicKey: senderPublicKey,
      secretKey: receiverPrivateKey,
    );
  }

  /// Reconstruye una SecureKey a partir de los bytes guardados
  /// en almacenamiento seguro (para cuando el usuario ya tiene cuenta
  /// y solo necesita recargar su clave privada al abrir la app).
  SecureKey loadPrivateKey(Uint8List bytes) =>
      SecureKey.fromList(_sodium, bytes);

  Uint8List stringToBytes(String text) => Uint8List.fromList(utf8.encode(text));

  String bytesToString(Uint8List bytes) => utf8.decode(bytes);
}
