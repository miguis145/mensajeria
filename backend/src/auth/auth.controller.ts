import type { Request, Response } from 'express';
import { hashPassword, verifyPassword, generateToken } from './auth.service.js';
import { createUser, findUserByUsername } from './user.repository.js';

const USERNAME_RE = /^[a-zA-Z0-9_]{3,32}$/;
const PUBLIC_KEY_BYTES = 32; // crypto_box usa claves curve25519 de 32 bytes

function validateRegistration(username: unknown, password: unknown, publicKey: unknown): string | null {
  if (typeof username !== 'string' || !USERNAME_RE.test(username)) {
    return 'username: 3 a 32 caracteres (letras, números o _)';
  }
  if (typeof password !== 'string' || password.length < 8 || password.length > 128) {
    return 'password: entre 8 y 128 caracteres';
  }
  if (typeof publicKey !== 'string' || Buffer.from(publicKey, 'base64').length !== PUBLIC_KEY_BYTES) {
    return 'publicKey inválida';
  }
  return null;
}

export async function registerHandler(req: Request, res: Response): Promise<void> {
  const { username, password, publicKey } = req.body;

  if (!username || !password || !publicKey) {
    res.status(400).json({ error: 'Faltan campos: username, password, publicKey' });
    return;
  }

  const invalid = validateRegistration(username, password, publicKey);
  if (invalid) {
    res.status(400).json({ error: invalid });
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

export async function loginHandler(req: Request, res: Response): Promise<void> {
  const { username, password } = req.body;

  if (!username || !password) {
    res.status(400).json({ error: 'Faltan campos: username, password' });
    return;
  }

  if (typeof username !== 'string' || typeof password !== 'string' || password.length > 128) {
    res.status(400).json({ error: 'Campos inválidos' });
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