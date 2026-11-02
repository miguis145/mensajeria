import { pool } from '../db/client.js';
import { MessageRow } from '../db/schema.js';

export class MessageRepository {
  async createMessage(params: {
    senderId: string;
    receiverId: string;
    type: 'text' | 'audio';
    ciphertext: Buffer;
    nonce: Buffer;
    audioBlob?: Buffer | null;
    senderExpiresAt: Date;
    receiverExpiresAt: Date;
  }): Promise<MessageRow> {
    const query = `
      INSERT INTO messages (
        sender_id, receiver_id, type, ciphertext, nonce, audio_blob,
        sender_expires_at, receiver_expires_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING *;
    `;
    const values = [
      params.senderId,
      params.receiverId,
      params.type,
      params.ciphertext,
      params.nonce,
      params.audioBlob || null,
      params.senderExpiresAt,
      params.receiverExpiresAt,
    ];
    const { rows } = await pool.query<MessageRow>(query, values);
    return rows[0];
  }

  async getMessagesForUser(userId: string): Promise<MessageRow[]> {
    // Cada usuario ve SOLO su copia y solo mientras la caducidad de SU lado
    // no haya vencido. Devolvemos "expires_at" ya resuelta para quien consulta.
    const query = `
      SELECT *,
             CASE WHEN receiver_id = $1 THEN receiver_expires_at
                  ELSE sender_expires_at END AS expires_at
        FROM messages
       WHERE (receiver_id = $1 AND receiver_expires_at > NOW())
          OR (sender_id   = $1 AND sender_expires_at   > NOW())
       ORDER BY sent_at ASC;
    `;
    const { rows } = await pool.query<MessageRow>(query, [userId]);
    return rows;
  }

  async markAsDelivered(messageId: string): Promise<void> {
    await pool.query(
      'UPDATE messages SET delivered_at = NOW() WHERE id = $1 AND delivered_at IS NULL;',
      [messageId]
    );
  }

  async markAsRead(messageId: string, receiverId: string): Promise<void> {
    // El "AND receiver_id = $2" evita que otro usuario marque mensajes ajenos
    await pool.query(
      'UPDATE messages SET read_at = NOW() WHERE id = $1 AND receiver_id = $2 AND read_at IS NULL;',
      [messageId, receiverId]
    );
  }

  async deleteExpiredMessages(): Promise<number> {
    const result = await pool.query('DELETE FROM messages WHERE sender_expires_at <= NOW() AND receiver_expires_at <= NOW();');
    return result.rowCount ?? 0;
  }
}

export const messageRepository = new MessageRepository();