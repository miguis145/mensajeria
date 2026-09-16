export interface User {
  id: string | number;
  username: string;
  password_hash: string;
  public_key?: string;
  created_at?: Date;
}

export interface EncryptedMessagePayload {
  recipientId: string | number;
  ciphertext: string; // base64 o hex
  nonce: string;
  type?: 'text' | 'audio';
  expiresInSeconds?: number;
}

export interface MessageRecord {
  id: string | number;
  sender_id: string | number;
  recipient_id: string | number;
  ciphertext: string;
  nonce: string;
  message_type: 'text' | 'audio';
  expires_at?: Date | null;
  created_at: Date;
}

export type MessageType = 'text' | 'audio';

export interface SendMessageDTO {
  receiverId: string;
  type: MessageType;
  ciphertext: string; // Base64 desde el cliente
  nonce: string;      // Base64 desde el cliente
  audioBlob?: string; // Base64 opcional si es audio
  expirySeconds?: number;
}

export interface AuthenticatedUser {
  userId: string;
  username: string;
}