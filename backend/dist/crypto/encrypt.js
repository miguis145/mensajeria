import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const sodium = require('libsodium-wrappers');
await sodium.ready;
export function encryptMessage(message, receiverPublicKey, senderPrivateKey) {
    const nonce = sodium.randombytes_buf(sodium.crypto_box_NONCEBYTES);
    const ciphertext = sodium.crypto_box_easy(message, nonce, receiverPublicKey, senderPrivateKey);
    return { ciphertext, nonce };
}
export function decryptMessage(ciphertext, nonce, senderPublicKey, receiverPrivateKey) {
    const decrypted = sodium.crypto_box_open_easy(ciphertext, nonce, senderPublicKey, receiverPrivateKey);
    if (decrypted === false) {
        throw new Error('No se pudo descifrar: mensaje corrupto o claves incorrectas');
    }
    return decrypted;
}
export function stringToBytes(text) {
    return sodium.from_string(text);
}
export function bytesToString(bytes) {
    return sodium.to_string(bytes);
}
//# sourceMappingURL=encrypt.js.map