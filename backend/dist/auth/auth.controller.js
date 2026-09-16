import { hashPassword, verifyPassword, generateToken } from './auth.service.js';
import { createUser, findUserByUsername } from './user.repository.js';
export async function registerHandler(req, res) {
    const { username, password, publicKey } = req.body;
    if (!username || !password || !publicKey) {
        res.status(400).json({ error: 'Faltan campos: username, password, publicKey' });
        return;
    }
    const existing = await findUserByUsername(username);
    if (existing) {
        res.status(409).json({ error: 'Ese username ya está en uso' });
        return;
    }
    const passwordHash = await hashPassword(password);
    const publicKeyBuffer = Buffer.from(publicKey, 'base64');
    const user = await createUser({
        username,
        passwordHash,
        publicKey: publicKeyBuffer,
    });
    const token = generateToken({ userId: user.id, username: user.username });
    res.status(201).json({ token, userId: user.id });
}
export async function loginHandler(req, res) {
    const { username, password } = req.body;
    if (!username || !password) {
        res.status(400).json({ error: 'Faltan campos: username, password' });
        return;
    }
    const user = await findUserByUsername(username);
    if (!user) {
        res.status(401).json({ error: 'Credenciales inválidas' });
        return;
    }
    const passwordValida = await verifyPassword(password, user.password_hash);
    if (!passwordValida) {
        res.status(401).json({ error: 'Credenciales inválidas' });
        return;
    }
    const token = generateToken({ userId: user.id, username: user.username });
    res.status(200).json({ token, userId: user.id });
}
//# sourceMappingURL=auth.controller.js.map