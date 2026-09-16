import sodium from 'libsodium-wrappers';
export async function generateKeyPair() {
    await sodium.ready;
    const keyPair = sodium.crypto_box_keypair();
    return {
        publicKey: Buffer.from(keyPair.publicKey),
        privateKey: Buffer.from(keyPair.privateKey),
    };
}
//# sourceMappingURL=keys.js.map