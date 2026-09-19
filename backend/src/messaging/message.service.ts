import { messageRepository } from './message.repository.js';
import { SendMessageDTO } from '../shared/types.js';
import { MessageRow } from '../db/schema.js';
import { pool } from '../db/client.js';

export class MessageService {
  async send(senderId: string, dto: SendMessageDTO): Promise<MessageRow> {
    // Si no se especifica caducidad, obtenemos el valor por defecto del receptor
    let expirySeconds: number = dto.expirySeconds ?? 86400;
    if (!dto.expirySeconds) {
      const userRes = await pool.query<{ default_expiry_seconds: number }>(
        'SELECT default_expiry_seconds FROM users WHERE id = $1',
        [dto.receiverId]
      );
      expirySeconds = userRes.rows[0]?.default_expiry_seconds ?? 86400; // 24h por defecto
    }

    const expiresAt = new Date(Date.now() + expirySeconds * 1000);

    return messageRepository.createMessage({
      senderId,
      receiverId: dto.receiverId,
      type: dto.type,
      ciphertext: Buffer.from(dto.ciphertext, 'base64'),
      nonce: Buffer.from(dto.nonce, 'base64'),
      audioBlob: dto.audioBlob ? Buffer.from(dto.audioBlob, 'base64') : null,
      expiresAt,
    });
  }

  async getConversation(userId: string): Promise<MessageRow[]> {
    return messageRepository.getMessagesForUser(userId);
  }

  async markDelivered(messageId: string): Promise<void> {
    await messageRepository.markAsDelivered(messageId);
  }

  async markRead(messageId: string): Promise<void> {
    await messageRepository.markAsRead(messageId);
  }
}

export const messageService = new MessageService();