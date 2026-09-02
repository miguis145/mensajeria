import { describe, it, expect } from 'vitest';
import {
  hashPassword,
  verifyPassword,
  generateToken,
  verifyToken,
} from './auth.service';

describe('hashing de contraseñas', () => {
  it('verifica correctamente la contraseña correcta', async () => {
    const hash = await hashPassword('miPasswordSegura123');
    const esValida = await verifyPassword('miPasswordSegura123', hash);
    expect(esValida).toBe(true);
  });

  it('rechaza una contraseña incorrecta', async () => {
    const hash = await hashPassword('miPasswordSegura123');
    const esValida = await verifyPassword('passwordEquivocada', hash);
    expect(esValida).toBe(false);
  });

  it('nunca guarda la contraseña en texto plano dentro del hash', async () => {
    const password = 'miPasswordSegura123';
    const hash = await hashPassword(password);
    expect(hash).not.toContain(password);
  });
});

describe('JWT (tokens de sesión)', () => {
  it('genera un token que se puede verificar correctamente', () => {
    const token = generateToken({ userId: 'abc123', username: 'fr4nk' });
    const payload = verifyToken(token);

    expect(payload.userId).toBe('abc123');
    expect(payload.username).toBe('fr4nk');
  });

  it('rechaza un token manipulado', () => {
    const token = generateToken({ userId: 'abc123', username: 'fr4nk' });
    const tokenManipulado = token.slice(0, -5) + 'xxxxx';

    expect(() => verifyToken(tokenManipulado)).toThrow();
  });
});
