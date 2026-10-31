import { pool } from '../db/client.js';
import type { UserRow } from '../db/schema.js';

export async function createUser(params: {
  username: string;
  passwordHash: string;
  publicKey: Buffer;
}): Promise<UserRow> {
  const { rows } = await pool.query<UserRow>(
    `INSERT INTO users (username, password_hash, public_key)
     VALUES ($1, $2, $3)
     RETURNING *`,
    [params.username, params.passwordHash, params.publicKey]
  );
  return rows[0];
}

export async function findUserByUsername(
  username: string
): Promise<UserRow | null> {
  const { rows } = await pool.query<UserRow>(
    'SELECT * FROM users WHERE username = $1',
    [username]
  );
  return rows[0] ?? null;
}

export async function listUsersExcept(userId: string): Promise<UserRow[]> {
  const { rows } = await pool.query<UserRow>(
    'SELECT * FROM users WHERE id != $1 ORDER BY username ASC',
    [userId]
  );
  return rows;
}

export async function findUserById(userId: string): Promise<UserRow | null> {
  const { rows } = await pool.query<UserRow>(
    'SELECT * FROM users WHERE id = $1',
    [userId]
  );
  return rows[0] ?? null;
}

export async function updateDefaultExpiry(
  userId: string,
  seconds: number
): Promise<UserRow> {
  const { rows } = await pool.query<UserRow>(
    `UPDATE users SET default_expiry_seconds = $2
     WHERE id = $1
     RETURNING *`,
    [userId, seconds]
  );
  return rows[0];
}