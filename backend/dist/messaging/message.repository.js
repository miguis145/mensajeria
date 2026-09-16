import { pool } from '../db/client.js';
export class MessageRepository {
    async createMessage(params) {
        const query = `
      INSERT INTO messages (
        sender_id, receiver_id, type, ciphertext, nonce, audio_blob, expires_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *;
    `;
        const values = [
            params.senderId,
            params.receiverId,
            params.type,
            params.ciphertext,
            params.nonce,
            params.audioBlob || null,
            params.expiresAt,
        ];
        const { rows } = await pool.query(query, values);
        return rows[0];
    }
    async getMessagesForUser(userId) {
        const query = `
      SELECT * FROM messages 
      WHERE (receiver_id = $1 OR sender_id = $1)
        AND expires_at > NOW()
      ORDER BY sent_at ASC;
    `;
        const { rows } = await pool.query(query, [userId]);
        return rows;
    }
    async markAsDelivered(messageId) {
        await pool.query('UPDATE messages SET delivered_at = NOW() WHERE id = $1 AND delivered_at IS NULL;', [messageId]);
    }
    async markAsRead(messageId) {
        await pool.query('UPDATE messages SET read_at = NOW() WHERE id = $1 AND read_at IS NULL;', [messageId]);
    }
    async deleteExpiredMessages() {
        const result = await pool.query('DELETE FROM messages WHERE expires_at <= NOW();');
        return result.rowCount ?? 0;
    }
}
export const messageRepository = new MessageRepository();
//# sourceMappingURL=message.repository.js.map