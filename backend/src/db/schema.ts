export interface UserRow {
  id: string;
  username: string;
  password_hash: string;
  public_key: Buffer;
  default_expiry_seconds: number;
  created_at: Date;
}

export interface MessageRow {
  id: string;
  sender_id: string;
  receiver_id: string;
  type: 'text' | 'audio';
  ciphertext: Buffer;
  nonce: Buffer;
  audio_blob: Buffer | null;
  sent_at: Date;
  delivered_at: Date | null;
  read_at: Date | null;
  sender_expires_at: Date;
  receiver_expires_at: Date;
  /** Solo en consultas por usuario: la caducidad de la copia de QUIEN consulta */
  expires_at?: Date;
}