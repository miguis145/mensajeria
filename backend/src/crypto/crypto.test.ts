import { describe, it, expect } from 'vitest';
import { createRequire } from 'module';
import { encryptMessage, decryptMessage, stringToBytes, bytesToString } from './encrypt';

const require = createRequire(import.meta.url);
const sodium = require('libsodium-wrappers');

await sodium.ready;

describe('cifrado E2EE con crypto_box', () => {
  it('descifra correctamente lo que cifró', () => {
    const sender = sodium.crypto_box_keypair();
    const receiver = sodium.crypto_box_keypair();

    const mensajeOriginal = 'Hola familia, esto es una prueba';
    const { ciphertext, nonce } = encryptMessage(
      stringToBytes(mensajeOriginal),
      receiver.publicKey,
      sender.privateKey
    );

    const descifrado = decryptMessage(
      ciphertext,
      nonce,
      sender.publicKey,
      receiver.privateKey
    );

    expect(bytesToString(descifrado)).toBe(mensajeOriginal);
  });

  it('falla si el ciphertext fue alterado', () => {
    const sender = sodium.crypto_box_keypair();
    const receiver = sodium.crypto_box_keypair();

    const { ciphertext, nonce } = encryptMessage(
      stringToBytes('mensaje secreto'),
      receiver.publicKey,
      sender.privateKey
    );

    ciphertext[0] ^= 1;

    expect(() =>
      decryptMessage(ciphertext, nonce, sender.publicKey, receiver.privateKey)
    ).toThrow();
  });

  it('genera nonces distintos en cada llamada', () => {
    const sender = sodium.crypto_box_keypair();
    const receiver = sodium.crypto_box_keypair();

    const a = encryptMessage(stringToBytes('hola'), receiver.publicKey, sender.privateKey);
    const b = encryptMessage(stringToBytes('hola'), receiver.publicKey, sender.privateKey);

    expect(a.nonce).not.toEqual(b.nonce);
  });
});