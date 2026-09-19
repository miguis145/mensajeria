import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const sodium = require('libsodium-wrappers');

export async function generateNonce(): Promise<Buffer> {
  await sodium.ready;
  const nonce = sodium.randombytes_buf(sodium.crypto_box_NONCEBYTES);
  return Buffer.from(nonce);
}