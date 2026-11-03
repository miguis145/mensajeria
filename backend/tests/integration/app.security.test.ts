import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';

vi.hoisted(() => {
  process.env.DATABASE_URL ??= 'postgresql://x:x@localhost:5432/x';
  process.env.JWT_SECRET ??= 'secreto-de-prueba';
});

vi.mock('../../src/auth/user.repository');
vi.mock('../../src/messaging/message.service');

import { app } from '../../src/app';
import { generateToken } from '../../src/auth/auth.service';
import * as userRepository from '../../src/auth/user.repository';
import { messageService } from '../../src/messaging/message.service';

const ANA = '11111111-1111-4111-8111-111111111111';
const BETO = '22222222-2222-4222-8222-222222222222';
const auth = (userId: string) => ({ Authorization: `Bearer ${generateToken({ userId, username: 'u' })}` });

const row = {
  id: '33333333-3333-4333-8333-333333333333',
  sender_id: ANA,
  receiver_id: BETO,
  type: 'text' as const,
  ciphertext: Buffer.from('cifrado'),
  nonce: Buffer.alloc(24, 1),
  audio_blob: null,
  sent_at: new Date('2026-11-03T10:00:00Z'),
  delivered_at: null,
  read_at: null,
  sender_expires_at: new Date('2026-11-03T10:02:00Z'),
  receiver_expires_at: new Date('2026-11-04T10:00:00Z'),
};

describe('GET /messages', () => {
  beforeEach(() => vi.clearAllMocks());

  it('exige autenticación', async () => {
    expect((await request(app).get('/messages')).status).toBe(401);
  });

  it('devuelve base64 (no Buffers JSON) y la caducidad de quien consulta', async () => {
    vi.mocked(messageService.getConversation).mockResolvedValue([row]);

    const asBeto = await request(app).get('/messages').set(auth(BETO));
    expect(asBeto.status).toBe(200);
    const m = asBeto.body.messages[0];
    expect(typeof m.ciphertext).toBe('string');
    expect(Buffer.from(m.ciphertext, 'base64').toString()).toBe('cifrado');
    expect(m.expires_at).toBe(row.receiver_expires_at.toISOString());

    const asAna = await request(app).get('/messages').set(auth(ANA));
    expect(asAna.body.messages[0].expires_at).toBe(row.sender_expires_at.toISOString());
  });

  it('no filtra el detalle de un error interno', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    vi.mocked(messageService.getConversation).mockRejectedValue(
      new Error('password authentication failed for user "postgres"'),
    );
    const res = await request(app).get('/messages').set(auth(ANA));
    expect(res.status).toBe(500);
    expect(res.body.error).toBe('Error interno');
    expect(JSON.stringify(res.body)).not.toContain('postgres');
  });
});

describe('PATCH /settings', () => {
  it.each([[30], [60.5], ['3600'], [3_000_000], [null]])('rechaza %s', async (valor) => {
    const res = await request(app)
      .patch('/settings')
      .set(auth(ANA))
      .send({ defaultExpirySeconds: valor });
    expect(res.status).toBe(400);
    expect(userRepository.updateDefaultExpiry).not.toHaveBeenCalled();
  });

  it('acepta un entero dentro del rango', async () => {
    vi.mocked(userRepository.updateDefaultExpiry).mockResolvedValue({ default_expiry_seconds: 3600 } as any);
    const res = await request(app).patch('/settings').set(auth(ANA)).send({ defaultExpirySeconds: 3600 });
    expect(res.status).toBe(200);
    expect(res.body.defaultExpirySeconds).toBe(3600);
  });
});

describe('endurecimiento HTTP', () => {
  it('helmet añade cabeceras de seguridad', async () => {
    const res = await request(app).get('/health');
    expect(res.headers['x-content-type-options']).toBe('nosniff');
    expect(res.headers['x-powered-by']).toBeUndefined();
  });

  it('rechaza cuerpos JSON de más de 100 KB', async () => {
    const res = await request(app)
      .post('/auth/login')
      .send({ username: 'a', password: 'x'.repeat(200 * 1024) });
    expect(res.status).toBe(413);
  });

  // Este test va el último: agota el límite de intentos de la IP de pruebas
  it('limita los intentos de login: el 21º recibe 429', async () => {
    vi.mocked(userRepository.findUserByUsername).mockResolvedValue(null);
    let ultimo = 0;
    for (let i = 0; i < 25; i++) {
      const r = await request(app).post('/auth/login').send({ username: 'x', password: 'y' });
      ultimo = r.status;
      if (r.status === 429) break;
    }
    expect(ultimo).toBe(429);
  });
});
