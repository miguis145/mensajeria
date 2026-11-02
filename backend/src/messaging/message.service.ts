import { messageRepository } from './message.repository.js';
import { SendMessageDTO } from '../shared/types.js';
import { MessageRow } from '../db/schema.js';
import { pool } from '../db/client.js';
import { AppError } from '../shared/errors.js';

const DEFAULT_EXPIRY_SECONDS = 86400; // 24 h

export class MessageService {
  async send(senderId: string, dto: SendMessageDTO): Promise<MessageRow> {
    // Regla: cada lado tiene SU propia caducidad sobre SU copia.
    //  - Emisor: la elegida para este mensaje (si viene) o su valor por defecto.
    //  - Receptor: siempre su propio valor por defecto.
    // Ninguno afecta al otro. El servidor borra la fila cuando vencen ambas.
    const { rows } = await pool.query<{ id: string; default_expiry_seconds: number }>(
      'SELECT id, default_expiry_seconds FROM users WHERE id = ANY($1::uuid[])',
      [[senderId, dto.receiverId]],
    );
    const defaultOf = (id: string) =>
      rows.find((r) => r.id === id)?.default_expiry_seconds ?? DEFAULT_EXPIRY_SECONDS;

    const now = Date.now();
    const senderSeconds = dto.expirySeconds ?? defaultOf(senderId);
    const receiverSeconds = defaultOf(dto.receiverId);
    const senderExpiresAt = new Date(now + senderSeconds * 1000);
    const receiverExpiresAt = new Date(now + receiverSeconds * 1000);

    try {
      return await messageRepository.createMessage({
        senderId,
        receiverId: dto.receiverId,
        type: dto.type,
        ciphertext: Buffer.from(dto.ciphertext, 'base64'),
        nonce: Buffer.from(dto.nonce, 'base64'),
        audioBlob: dto.audioBlob ? Buffer.from(dto.audioBlob, 'base64') : null,
        senderExpiresAt,
        receiverExpiresAt,
      });
    } catch (err: any) {
      // 23503 = violación de clave foránea (el receptor no existe)
      if (err?.code === '23503') throw new AppError('Destinatario no encontrado', 404);
      throw err;
    }
  }

  async getConversation(userId: string): Promise<MessageRow[]> {
    return messageRepository.getMessagesForUser(userId);
  }

  async markDelivered(messageId: string): Promise<void> {
    await messageRepository.markAsDelivered(messageId);
  }

  /** Solo el RECEPTOR del mensaje puede marcarlo como leído. */
  async markRead(messageId: string, userId: string): Promise<void> {
    await messageRepository.markAsRead(messageId, userId);
  }
}

export const messageService = new MessageService();
