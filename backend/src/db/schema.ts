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
  expires_at: Date;
}