import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const sodium = require('libsodium-wrappers');

export interface KeyPair {
  publicKey: Buffer;
  privateKey: Buffer;
}

export async function generateKeyPair(): Promise<KeyPair> {
  await sodium.ready;
  const keyPair = sodium.crypto_box_keypair();
  return {
    publicKey: Buffer.from(keyPair.publicKey),
    privateKey: Buffer.from(keyPair.privateKey),
  };
}