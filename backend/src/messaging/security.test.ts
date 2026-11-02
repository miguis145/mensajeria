import { describe, it, expect, vi, beforeAll, afterAll, beforeEach } from 'vitest';

vi.hoisted(() => {
  process.env.DATABASE_URL ??= 'postgresql://x:x@localhost:5432/x';
  process.env.JWT_SECRET ??= 'secreto-de-prueba';
});

vi.mock('../db/client.js', () => ({ pool: { query: vi.fn() } }));
vi.mock('./message.repository.js', () => ({
  messageRepository: {
    createMessage: vi.fn(),
    markAsDelivered: vi.fn(),
    markAsRead: vi.fn(),
    getMessagesForUser: vi.fn(),
  },
}));

import http from 'node:http';
import type { AddressInfo } from 'node:net';
import WebSocket from 'ws';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { pool } from '../db/client.js';
import { messageRepository } from './message.repository.js';
import { messageService } from './message.service.js';
import { initWebSocketServer } from './ws.server.js';

const A = '11111111-1111-4111-8111-111111111111';
const B = '22222222-2222-4222-8222-222222222222';
const MSG = '33333333-3333-4333-8333-333333333333';
const nonce = Buffer.alloc(24, 7).toString('base64');
const ct = Buffer.from('cifrado').toString('base64');
const tokenFor = (userId: string) => jwt.sign({ userId, username: 'u' }, env.jwtSecret);

let server: http.Server;
let port: number;

beforeAll(async () => {
  server = http.createServer();
  initWebSocketServer(server);
  await new Promise<void>((r) => server.listen(0, r));
  port = (server.address() as AddressInfo).port;
});
afterAll(() => new Promise<void>((r) => server.close(() => r())));
beforeEach(() => {
  vi.clearAllMocks();
});

function connect(userId: string): Promise<WebSocket> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://localhost:${port}/?token=${tokenFor(userId)}`);
    ws.once('open', () => resolve(ws));
    ws.once('error', reject);
  });
}
const nextMessage = (ws: WebSocket) =>
  new Promise<any>((r) => ws.once('message', (d) => r(JSON.parse(d.toString()))));

describe('mark_read', () => {
  it('pasa el userId autenticado al repositorio (solo el receptor puede marcar)', async () => {
    const ws = await connect(B);
    ws.send(JSON.stringify({ type: 'mark_read', messageId: MSG }));
    await vi.waitFor(() => expect(messageRepository.markAsRead).toHaveBeenCalledWith(MSG, B));
    ws.close();
  });

  it('rechaza un messageId que no es UUID sin tocar la base de datos', async () => {
    const ws = await connect(B);
    const reply = nextMessage(ws);
    ws.send(JSON.stringify({ type: 'mark_read', messageId: "1' OR '1'='1" }));
    expect((await reply).message).toMatch(/messageId/);
    expect(messageRepository.markAsRead).not.toHaveBeenCalled();
    ws.close();
  });
});

describe('send_message', () => {
  it('rechaza expirySeconds negativo sin guardar nada', async () => {
    const ws = await connect(A);
    const reply = nextMessage(ws);
    ws.send(JSON.stringify({
      type: 'send_message',
      payload: { receiverId: B, type: 'text', ciphertext: ct, nonce, expirySeconds: -10 },
    }));
    expect((await reply).type).toBe('error');
    expect(messageRepository.createMessage).not.toHaveBeenCalled();
    ws.close();
  });

  it('no filtra errores internos al cliente', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    vi.mocked(pool.query).mockResolvedValue({ rows: [{ default_expiry_seconds: 3600 }] } as any);
    vi.mocked(messageRepository.createMessage).mockRejectedValue(
      new Error('connection to server at "10.0.0.5" failed'),
    );
    const ws = await connect(A);
    const reply = nextMessage(ws);
    ws.send(JSON.stringify({
      type: 'send_message',
      payload: { receiverId: B, type: 'text', ciphertext: ct, nonce },
    }));
    const msg = await reply;
    expect(msg.message).toBe('Error interno');
    expect(JSON.stringify(msg)).not.toContain('10.0.0.5');
    ws.close();
  });

  it('cierra la conexión si el mensaje supera maxPayload', async () => {
    const ws = await connect(A);
    const closed = new Promise<number>((r) => ws.once('close', (code) => r(code)));
    ws.send('x'.repeat(16 * 1024 * 1024));
    expect(await closed).toBe(1009); // Message too big
  });
});

describe('MessageService: cada lado tiene su propia caducidad', () => {
  const rowsFor = (emisor: number, receptor: number) =>
    ({ rows: [{ id: A, default_expiry_seconds: emisor }, { id: B, default_expiry_seconds: receptor }] }) as any;

  it('emisor y receptor usan cada uno SU valor y no se afectan', async () => {
    vi.mocked(pool.query).mockResolvedValue(rowsFor(120, 86400));
    vi.mocked(messageRepository.createMessage).mockResolvedValue({} as any);
    const before = Date.now();
    await messageService.send(A, { receiverId: B, type: 'text', ciphertext: ct, nonce });
    const { senderExpiresAt, receiverExpiresAt } = vi.mocked(messageRepository.createMessage).mock.calls[0][0];
    expect(senderExpiresAt.getTime() - before).toBeGreaterThanOrEqual(119_000);
    expect(senderExpiresAt.getTime() - before).toBeLessThan(125_000);
    expect(receiverExpiresAt.getTime() - before).toBeGreaterThanOrEqual(86_399_000);
  });

  it('expirySeconds del mensaje solo cambia la copia del emisor', async () => {
    vi.mocked(pool.query).mockResolvedValue(rowsFor(3600, 7200));
    vi.mocked(messageRepository.createMessage).mockResolvedValue({} as any);
    const before = Date.now();
    await messageService.send(A, { receiverId: B, type: 'text', ciphertext: ct, nonce, expirySeconds: 60 });
    const { senderExpiresAt, receiverExpiresAt } = vi.mocked(messageRepository.createMessage).mock.calls[0][0];
    expect(senderExpiresAt.getTime() - before).toBeLessThan(65_000);
    expect(receiverExpiresAt.getTime() - before).toBeGreaterThanOrEqual(7_199_000);
  });

  it('traduce la violación de clave foránea a "Destinatario no encontrado"', async () => {
    vi.mocked(pool.query).mockResolvedValue({ rows: [] } as any);
    vi.mocked(messageRepository.createMessage).mockRejectedValue(Object.assign(new Error('fk'), { code: '23503' }));
    await expect(
      messageService.send(A, { receiverId: B, type: 'text', ciphertext: ct, nonce, expirySeconds: 60 }),
    ).rejects.toThrow(/Destinatario/);
  });
});
