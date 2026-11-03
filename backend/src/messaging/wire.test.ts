import { describe, it, expect } from 'vitest';
import { toWireMessage } from './wire.js';
import type { MessageRow } from '../db/schema.js';

const ANA = '11111111-1111-4111-8111-111111111111';
const BETO = '22222222-2222-4222-8222-222222222222';

const row: MessageRow = {
  id: '33333333-3333-4333-8333-333333333333',
  sender_id: ANA,
  receiver_id: BETO,
  type: 'text',
  ciphertext: Buffer.from('cifrado'),
  nonce: Buffer.alloc(24, 9),
  audio_blob: null,
  sent_at: new Date('2026-11-03T10:00:00Z'),
  delivered_at: null,
  read_at: null,
  sender_expires_at: new Date('2026-11-03T10:02:00Z'),
  receiver_expires_at: new Date('2026-11-04T10:00:00Z'),
};

describe('toWireMessage', () => {
  it('convierte los Buffers a base64', () => {
    const w = toWireMessage(row, BETO);
    expect(Buffer.from(w.ciphertext, 'base64').toString()).toBe('cifrado');
    expect(Buffer.from(w.nonce, 'base64')).toHaveLength(24);
    expect(w.audioBlob).toBeUndefined();
  });

  it('cada lado recibe SU caducidad', () => {
    expect(toWireMessage(row, BETO).expires_at).toEqual(row.receiver_expires_at);
    expect(toWireMessage(row, ANA).expires_at).toEqual(row.sender_expires_at);
  });

  it('incluye emisor y receptor para que el cliente sepa con quién es la conversación', () => {
    const w = toWireMessage(row, ANA);
    expect(w.senderId).toBe(ANA);
    expect(w.receiverId).toBe(BETO);
  });
});
