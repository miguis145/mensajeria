import { describe, it, expect, vi, beforeEach } from 'vitest';
import express from 'express';
import request from 'supertest';
import { registerHandler, loginHandler } from './auth.controller';
import * as userRepository from './user.repository';
import { hashPassword } from './auth.service';

vi.mock('./user.repository');

function buildTestApp() {
  const app = express();
  app.use(express.json());
  app.post('/register', registerHandler);
  app.post('/login', loginHandler);
  return app;
}

describe('POST /register', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('registra un usuario nuevo y devuelve un token', async () => {
    vi.mocked(userRepository.findUserByUsername).mockResolvedValue(null);
    vi.mocked(userRepository.createUser).mockResolvedValue({
      id: 'user-1',
      username: 'fr4nk',
      password_hash: 'hash-falso',
      public_key: Buffer.from('clave-falsa'),
      default_expiry_seconds: 86400,
      created_at: new Date(),
    });

    const app = buildTestApp();
    const res = await request(app).post('/register').send({
      username: 'fr4nk',
      password: 'passwordSegura123',
      publicKey: Buffer.from('clave-publica-falsa').toString('base64'),
    });

    expect(res.status).toBe(201);
    expect(res.body.token).toBeDefined();
    expect(res.body.userId).toBe('user-1');
  });

  it('rechaza registro si el username ya existe', async () => {
    vi.mocked(userRepository.findUserByUsername).mockResolvedValue({
      id: 'existing-user',
      username: 'fr4nk',
      password_hash: 'algo',
      public_key: Buffer.from('algo'),
      default_expiry_seconds: 86400,
      created_at: new Date(),
    });

    const app = buildTestApp();
    const res = await request(app).post('/register').send({
      username: 'fr4nk',
      password: 'passwordSegura123',
      publicKey: Buffer.from('clave').toString('base64'),
    });

    expect(res.status).toBe(409);
  });

  it('rechaza registro con campos faltantes', async () => {
    const app = buildTestApp();
    const res = await request(app).post('/register').send({ username: 'fr4nk' });

    expect(res.status).toBe(400);
  });
});

describe('POST /login', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('inicia sesión con credenciales correctas', async () => {
    const hash = await hashPassword('passwordSegura123');
    vi.mocked(userRepository.findUserByUsername).mockResolvedValue({
      id: 'user-1',
      username: 'fr4nk',
      password_hash: hash,
      public_key: Buffer.from('clave'),
      default_expiry_seconds: 86400,
      created_at: new Date(),
    });

    const app = buildTestApp();
    const res = await request(app).post('/login').send({
      username: 'fr4nk',
      password: 'passwordSegura123',
    });

    expect(res.status).toBe(200);
    expect(res.body.token).toBeDefined();
  });

  it('rechaza login con contraseña incorrecta', async () => {
    const hash = await hashPassword('passwordSegura123');
    vi.mocked(userRepository.findUserByUsername).mockResolvedValue({
      id: 'user-1',
      username: 'fr4nk',
      password_hash: hash,
      public_key: Buffer.from('clave'),
      default_expiry_seconds: 86400,
      created_at: new Date(),
    });

    const app = buildTestApp();
    const res = await request(app).post('/login').send({
      username: 'fr4nk',
      password: 'passwordEquivocada',
    });

    expect(res.status).toBe(401);
  });

  it('rechaza login si el usuario no existe', async () => {
    vi.mocked(userRepository.findUserByUsername).mockResolvedValue(null);

    const app = buildTestApp();
    const res = await request(app).post('/login').send({
      username: 'no-existe',
      password: 'cualquiera',
    });

    expect(res.status).toBe(401);
  });
});
