import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const sodium = require('libsodium-wrappers');

await sodium.ready;
export interface EncryptedPayload {
  ciphertext: Uint8Array;
  nonce: Uint8Array;
}

export function encryptMessage(
  message: Uint8Array,
  receiverPublicKey: Uint8Array,
  senderPrivateKey: Uint8Array
): EncryptedPayload {
  const nonce = sodium.randombytes_buf(sodium.crypto_box_NONCEBYTES);

  const ciphertext = sodium.crypto_box_easy(
    message,
    nonce,
    receiverPublicKey,
    senderPrivateKey
  );

  return { ciphertext, nonce };
}

export function decryptMessage(
  ciphertext: Uint8Array,
  nonce: Uint8Array,
  senderPublicKey: Uint8Array,
  receiverPrivateKey: Uint8Array
): Uint8Array {
  const decrypted = sodium.crypto_box_open_easy(
    ciphertext,
    nonce,
    senderPublicKey,
    receiverPrivateKey
  );

  if (decrypted === false) {
    throw new Error('No se pudo descifrar: mensaje corrupto o claves incorrectas');
  }

  return decrypted;
}

export function stringToBytes(text: string): Uint8Array {
  return sodium.from_string(text);
}

export function bytesToString(bytes: Uint8Array): string {
  return sodium.to_string(bytes);
}