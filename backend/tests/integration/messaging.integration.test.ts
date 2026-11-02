import { describe, it, expect, vi, beforeAll, afterAll } from 'vitest';
import http from 'node:http';
import { WebSocket } from 'ws';
import { initWebSocketServer } from '../../src/messaging/ws.server';
import { generateToken } from '../../src/auth/auth.service';
import { messageService } from '../../src/messaging/message.service';

// Mockeamos la capa de negocio de mensajes: este test es sobre el WebSocket
// y la autenticación, no sobre guardar en la DB de verdad.
vi.mock('../../src/messaging/message.service');

let server: http.Server;
let port: number;

beforeAll(async () => {
  server = http.createServer();
  initWebSocketServer(server);

  await new Promise<void>((resolve) => {
    server.listen(0, () => {
      const address = server.address();
      port = typeof address === 'object' && address ? address.port : 0;
      resolve();
    });
  });
});

afterAll(() => {
  server.close();
});

function connect(): Promise<WebSocket> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://localhost:${port}`);
    ws.once('open', () => resolve(ws));
    ws.once('error', reject);
  });
}

function waitForMessage(ws: WebSocket): Promise<any> {
  return new Promise((resolve) => {
    ws.once('message', (data) => resolve(JSON.parse(data.toString())));
  });
}

function waitForClose(ws: WebSocket): Promise<number> {
  return new Promise((resolve) => {
    ws.once('close', (code) => resolve(code));
  });
}

const USER_1 = '11111111-1111-4111-8111-111111111111';
const USER_2 = '22222222-2222-4222-8222-222222222222';

describe('WebSocket: autenticación', () => {
  // Esta prueba existe específicamente porque un bug real (decoded.sub en
  // vez de decoded.userId) hacía que la autenticación por WebSocket
  // fallara SIEMPRE, aunque el token fuera válido.
  it('acepta un token válido y responde auth_success', async () => {
    const ws = await connect();
    const token = generateToken({ userId: 'user-1', username: 'fr4nk' });

    ws.send(JSON.stringify({ type: 'auth', token }));
    const response = await waitForMessage(ws);

    expect(response.type).toBe('auth_success');
    ws.close();
  });

  it('rechaza mensajes de tipo send_message si nunca se autenticó', async () => {
    const ws = await connect();

    ws.send(
      JSON.stringify({
        type: 'send_message',
        payload: { receiverId: 'x', type: 'text', ciphertext: 'a', nonce: 'b' },
      })
    );
    const response = await waitForMessage(ws);

    expect(response.type).toBe('error');
    expect(response.message).toMatch(/no autenticado/i);
    ws.close();
  });

  it('rechaza un token inválido cerrando la conexión con código 4001', async () => {
    const ws = await connect();
    const closed = waitForClose(ws);

    ws.send(JSON.stringify({ type: 'auth', token: 'token-falso-invalido' }));

    expect(await closed).toBe(4001);
  });
});

describe('WebSocket: envío de mensajes', () => {
  it('tras autenticarse, puede enviar un mensaje y recibe confirmación', async () => {
    vi.mocked(messageService.send).mockResolvedValue({
      id: 'msg-1',
      sender_id: USER_1,
      receiver_id: USER_2,
      type: 'text',
      ciphertext: Buffer.from('c'),
      nonce: Buffer.from('n'),
      audio_blob: null,
      sent_at: new Date(),
      delivered_at: null,
      read_at: null,
      sender_expires_at: new Date(),
      receiver_expires_at: new Date(),
    });

    const ws = await connect();
    const token = generateToken({ userId: USER_1, username: 'fr4nk' });

    ws.send(JSON.stringify({ type: 'auth', token }));
    await waitForMessage(ws); // auth_success

    ws.send(
      JSON.stringify({
        type: 'send_message',
        payload: {
          receiverId: USER_2,
          type: 'text',
          ciphertext: Buffer.from('abc').toString('base64'),
          nonce: Buffer.alloc(24, 1).toString('base64'), // crypto_box usa nonces de 24 bytes
        },
      })
    );
    const response = await waitForMessage(ws);

    expect(response.type).toBe('message_sent');
    expect(response.payload.id).toBe('msg-1');
    expect(response.payload.expires_at).toBeDefined(); // caducidad de la copia del emisor
    // Confirma que el userId autenticado (del token) es el que se usó como sender,
    // no un valor undefined (que era justo el síntoma del bug original)
    expect(messageService.send).toHaveBeenCalledWith(USER_1, expect.any(Object));

    ws.close();
  });
});
