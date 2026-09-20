import { describe, it, expect, vi, beforeEach } from 'vitest';
import { MessageService } from './message.service';
import { messageRepository } from './message.repository';
import { pool } from '../db/client';

vi.mock('./message.repository');
vi.mock('../db/client');

describe('MessageService.send', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('usa expirySeconds del DTO si viene especificado, sin consultar la DB', async () => {
    vi.mocked(messageRepository.createMessage).mockResolvedValue({
      id: 'msg-1',
      sender_id: 'sender-1',
      receiver_id: 'receiver-1',
      type: 'text',
      ciphertext: Buffer.from('cipher'),
      nonce: Buffer.from('nonce'),
      audio_blob: null,
      sent_at: new Date(),
      delivered_at: null,
      read_at: null,
      expires_at: new Date(),
    });

    const service = new MessageService();
    await service.send('sender-1', {
      receiverId: 'receiver-1',
      type: 'text',
      ciphertext: Buffer.from('hola').toString('base64'),
      nonce: Buffer.from('nonce-val').toString('base64'),
      expirySeconds: 3600,
    });

    // No debe consultar la DB para el default si el usuario ya especificó uno
    expect(pool.query).not.toHaveBeenCalled();
    expect(messageRepository.createMessage).toHaveBeenCalledWith(
      expect.objectContaining({ senderId: 'sender-1', receiverId: 'receiver-1' })
    );
  });

  it('consulta el default_expiry_seconds del receptor si no viene expirySeconds', async () => {
    vi.mocked(pool.query).mockResolvedValue({
      rows: [{ default_expiry_seconds: 7200 }],
    } as any);
    vi.mocked(messageRepository.createMessage).mockResolvedValue({
      id: 'msg-2',
      sender_id: 'sender-1',
      receiver_id: 'receiver-1',
      type: 'text',
      ciphertext: Buffer.from('c'),
      nonce: Buffer.from('n'),
      audio_blob: null,
      sent_at: new Date(),
      delivered_at: null,
      read_at: null,
      expires_at: new Date(),
    });

    const service = new MessageService();
    await service.send('sender-1', {
      receiverId: 'receiver-1',
      type: 'text',
      ciphertext: Buffer.from('hola').toString('base64'),
      nonce: Buffer.from('n').toString('base64'),
    });

    expect(pool.query).toHaveBeenCalledWith(
      expect.stringContaining('default_expiry_seconds'),
      ['receiver-1']
    );
  });

  it('cae en 86400 segundos (24h) si el usuario no tiene default configurado', async () => {
    vi.mocked(pool.query).mockResolvedValue({ rows: [] } as any);
    vi.mocked(messageRepository.createMessage).mockImplementation(async (params) => ({
      id: 'msg-3',
      sender_id: params.senderId,
      receiver_id: params.receiverId,
      type: params.type,
      ciphertext: params.ciphertext,
      nonce: params.nonce,
      audio_blob: null,
      sent_at: new Date(),
      delivered_at: null,
      read_at: null,
      expires_at: params.expiresAt,
    }));

    const service = new MessageService();
    const before = Date.now();
    const result = await service.send('sender-1', {
      receiverId: 'receiver-sin-default',
      type: 'text',
      ciphertext: Buffer.from('x').toString('base64'),
      nonce: Buffer.from('n').toString('base64'),
    });

    const expectedMinExpiry = before + 86400 * 1000 - 1000; // margen de 1s
    expect(result.expires_at.getTime()).toBeGreaterThan(expectedMinExpiry);
  });

  it('convierte correctamente ciphertext/nonce de base64 a Buffer', async () => {
    vi.mocked(messageRepository.createMessage).mockImplementation(async (params) => ({
      id: 'msg-4',
      sender_id: params.senderId,
      receiver_id: params.receiverId,
      type: params.type,
      ciphertext: params.ciphertext,
      nonce: params.nonce,
      audio_blob: params.audioBlob ?? null,
      sent_at: new Date(),
      delivered_at: null,
      read_at: null,
      expires_at: params.expiresAt,
    }));

    const service = new MessageService();
    const result = await service.send('sender-1', {
      receiverId: 'receiver-1',
      type: 'text',
      ciphertext: Buffer.from('mensaje secreto').toString('base64'),
      nonce: Buffer.from('nonce-123').toString('base64'),
      expirySeconds: 60,
    });

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
    const service = new MessageService();
    await service.getConversation('user-1');
    expect(messageRepository.getMessagesForUser).toHaveBeenCalledWith('user-1');
  });

  it('markDelivered delega en messageRepository.markAsDelivered', async () => {
    const service = new MessageService();
    await service.markDelivered('msg-1');
    expect(messageRepository.markAsDelivered).toHaveBeenCalledWith('msg-1');
  });

  it('markRead delega en messageRepository.markAsRead', async () => {
    const service = new MessageService();
    await service.markRead('msg-1');
    expect(messageRepository.markAsRead).toHaveBeenCalledWith('msg-1');
  });
});