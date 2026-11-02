import { describe, it, expect, vi, beforeEach } from 'vitest';
import { MessageService } from './message.service';
import { messageRepository } from './message.repository';
import { pool } from '../db/client';
import type { MessageRow } from '../db/schema';

vi.mock('./message.repository');
vi.mock('../db/client');

const SENDER = 'sender-1';
const RECEIVER = 'receiver-1';

/** Respuesta simulada de "SELECT id, default_expiry_seconds FROM users ..." */
function mockDefaults(sender?: number, receiver?: number) {
  const rows: { id: string; default_expiry_seconds: number }[] = [];
  if (sender !== undefined) rows.push({ id: SENDER, default_expiry_seconds: sender });
  if (receiver !== undefined) rows.push({ id: RECEIVER, default_expiry_seconds: receiver });
  vi.mocked(pool.query).mockResolvedValue({ rows } as any);
}

/** El repositorio devuelve la fila tal como la recibió el INSERT */
function echoRepository() {
  vi.mocked(messageRepository.createMessage).mockImplementation(
    async (params): Promise<MessageRow> => ({
      id: 'msg-1',
      sender_id: params.senderId,
      receiver_id: params.receiverId,
      type: params.type,
      ciphertext: params.ciphertext,
      nonce: params.nonce,
      audio_blob: params.audioBlob ?? null,
      sent_at: new Date(),
      delivered_at: null,
      read_at: null,
      sender_expires_at: params.senderExpiresAt,
      receiver_expires_at: params.receiverExpiresAt,
    }),
  );
}

const dto = (extra: object = {}) => ({
  receiverId: RECEIVER,
  type: 'text' as const,
  ciphertext: Buffer.from('hola').toString('base64'),
  nonce: Buffer.from('n').toString('base64'),
  ...extra,
});

const secondsFromNow = (d: Date, from: number) => Math.round((d.getTime() - from) / 1000);

describe('MessageService.send: cada lado tiene su propia caducidad', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    echoRepository();
  });

  it('el emisor usa su expirySeconds y el receptor SU propio default (no se afectan)', async () => {
    mockDefaults(100, 7200);
    const before = Date.now();
    const result = await new MessageService().send(SENDER, dto({ expirySeconds: 3600 }));

    expect(secondsFromNow(result.sender_expires_at, before)).toBe(3600);
    expect(secondsFromNow(result.receiver_expires_at, before)).toBe(7200);
  });

  it('sin expirySeconds, cada lado usa su default_expiry_seconds', async () => {
    mockDefaults(120, 86400);
    const before = Date.now();
    const result = await new MessageService().send(SENDER, dto());

    expect(secondsFromNow(result.sender_expires_at, before)).toBe(120);
    expect(secondsFromNow(result.receiver_expires_at, before)).toBe(86400);
  });

  it('consulta los defaults de emisor y receptor en una sola query', async () => {
    mockDefaults(60, 60);
    await new MessageService().send(SENDER, dto());

    expect(pool.query).toHaveBeenCalledTimes(1);
    expect(pool.query).toHaveBeenCalledWith(
      expect.stringContaining('default_expiry_seconds'),
      [[SENDER, RECEIVER]],
    );
  });

  it('cae en 86400 segundos (24h) para el lado que no tiene default configurado', async () => {
    mockDefaults(undefined, undefined);
    const before = Date.now();
    const result = await new MessageService().send(SENDER, dto());

    expect(secondsFromNow(result.sender_expires_at, before)).toBe(86400);
    expect(secondsFromNow(result.receiver_expires_at, before)).toBe(86400);
  });

  it('convierte correctamente ciphertext/nonce de base64 a Buffer', async () => {
    mockDefaults(60, 60);
    const result = await new MessageService().send(
      SENDER,
      dto({
        ciphertext: Buffer.from('mensaje secreto').toString('base64'),
        nonce: Buffer.from('nonce-123').toString('base64'),
        expirySeconds: 60,
      }),
    );

    expect(result.ciphertext.toString()).toBe('mensaje secreto');
    expect(result.nonce.toString()).toBe('nonce-123');
  });
});

describe('MessageService (delegación al repositorio)', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('getConversation delega en messageRepository.getMessagesForUser', async () => {
    vi.mocked(messageRepository.getMessagesForUser).mockResolvedValue([]);
    await new MessageService().getConversation('user-1');
    expect(messageRepository.getMessagesForUser).toHaveBeenCalledWith('user-1');
  });

  it('markDelivered delega en messageRepository.markAsDelivered', async () => {
    await new MessageService().markDelivered('msg-1');
    expect(messageRepository.markAsDelivered).toHaveBeenCalledWith('msg-1');
  });

  it('markRead pasa también el userId (solo el receptor puede marcar como leído)', async () => {
    await new MessageService().markRead('msg-1', 'user-1');
    expect(messageRepository.markAsRead).toHaveBeenCalledWith('msg-1', 'user-1');
  });
});
