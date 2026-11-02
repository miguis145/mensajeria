import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import { app } from '../../src/app';
import * as userRepository from '../../src/auth/user.repository';

vi.mock('../../src/auth/user.repository');

describe('Flujo completo de auth vía app real', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('responde ok en /health sin necesitar autenticación', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  it('permite registrar, y luego usar el token para acceder a /auth/me', async () => {
    vi.mocked(userRepository.findUserByUsername).mockResolvedValue(null);
    vi.mocked(userRepository.createUser).mockResolvedValue({
      id: 'user-1',
      username: 'fr4nk',
      password_hash: 'hash-falso',
      public_key: Buffer.from('clave'),
      default_expiry_seconds: 86400,
      created_at: new Date(),
    });

    const registerRes = await request(app).post('/auth/register').send({
      username: 'fr4nk',
      password: 'passwordSegura123',
      publicKey: Buffer.alloc(32, 1).toString('base64'),
    });

    expect(registerRes.status).toBe(201);
    const { token } = registerRes.body;

    const meRes = await request(app)
      .get('/auth/me')
      .set('Authorization', `Bearer ${token}`);

    expect(meRes.status).toBe(200);
    expect(meRes.body.user.username).toBe('fr4nk');
  });

  it('bloquea /auth/me sin token', async () => {
    const res = await request(app).get('/auth/me');
    expect(res.status).toBe(401);
  });
});
