import type { MessageRow } from '../db/schema.js';

/**
 * Formato único con el que el servidor entrega un mensaje a un cliente,
 * tanto por WebSocket ("new_message") como por HTTP (GET /messages).
 *
 * - Los Buffers viajan en base64 (res.json() de un Buffer da {type:'Buffer',data:[...]},
 *   que es enorme e inservible para el cliente).
 * - `expires_at` es la caducidad de la copia de QUIEN recibe: la del receptor si
 *   es el receptor, la del emisor si es el emisor. Cada lado ve solo la suya.
 */
export function toWireMessage(row: MessageRow, viewerId: string) {
  const expiresAt =
    viewerId === row.receiver_id ? row.receiver_expires_at : row.sender_expires_at;

  return {
    id: row.id,
    senderId: row.sender_id,
    receiverId: row.receiver_id,
    type: row.type,
    ciphertext: row.ciphertext.toString('base64'),
    nonce: row.nonce.toString('base64'),
    audioBlob: row.audio_blob ? row.audio_blob.toString('base64') : undefined,
    sent_at: row.sent_at,
    expires_at: expiresAt,
  };
}
