import { describe, it, expect } from 'vitest';
import express from 'express';
import request from 'supertest';
import { requireAuth } from './auth.middleware';
import { generateToken } from './auth.service';

function buildTestApp() {
  const app = express();
  app.get('/ruta-protegida', requireAuth, (req, res) => {
    res.status(200).json({ mensaje: 'acceso concedido', user: req.user });
  });
  return app;
}

describe('requireAuth middleware', () => {
  it('deja pasar con un token válido', async () => {
    const token = generateToken({ userId: 'user-1', username: 'fr4nk' });
    const app = buildTestApp();

    const res = await request(app)
      .get('/ruta-protegida')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.user.username).toBe('fr4nk');
  });

  it('rechaza sin header Authorization', async () => {
    const app = buildTestApp();
    const res = await request(app).get('/ruta-protegida');

    expect(res.status).toBe(401);
  });

  it('rechaza con formato de header incorrecto (sin "Bearer ")', async () => {
    const token = generateToken({ userId: 'user-1', username: 'fr4nk' });
    const app = buildTestApp();

    const res = await request(app)
      .get('/ruta-protegida')
      .set('Authorization', token);

    expect(res.status).toBe(401);
  });

  it('rechaza un token inválido', async () => {
    const app = buildTestApp();
    const res = await request(app)
      .get('/ruta-protegida')
      .set('Authorization', 'Bearer token-falso-invalido');

    expect(res.status).toBe(401);
  });
});
