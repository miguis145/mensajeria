// test/crypto_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/crypto/crypto_service.dart';

void main() {
  test('cifra y descifra correctamente (roundtrip)', () async {
    final crypto = await CryptoService.init();

    final sender = crypto.generateKeyPair();
    final receiver = crypto.generateKeyPair();

    const mensajeOriginal = 'Hola familia, prueba desde Flutter';
    final payload = crypto.encryptMessage(
      message: crypto.stringToBytes(mensajeOriginal),
      receiverPublicKey: receiver.publicKey,
      senderPrivateKey: sender.secretKey,
    );

    final descifrado = crypto.decryptMessage(
      ciphertext: payload.ciphertext,
      nonce: payload.nonce,
      senderPublicKey: sender.publicKey,
      receiverPrivateKey: receiver.secretKey,
    );

    expect(crypto.bytesToString(descifrado), mensajeOriginal);
  });
}