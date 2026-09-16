import sodium from 'libsodium-wrappers';
export async function generateNonce() {
    await sodium.ready;
    const nonce = sodium.randombytes_buf(sodium.crypto_box_NONCEBYTES);
    return Buffer.from(nonce);
}
//# sourceMappingURL=nonce.js.map