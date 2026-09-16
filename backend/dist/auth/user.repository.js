import { pool } from '../db/client.js';
export async function createUser(params) {
    const { rows } = await pool.query(`INSERT INTO users (username, password_hash, public_key)
     VALUES ($1, $2, $3)
     RETURNING *`, [params.username, params.passwordHash, params.publicKey]);
    return rows[0];
}
export async function findUserByUsername(username) {
    const { rows } = await pool.query('SELECT * FROM users WHERE username = $1', [username]);
    return rows[0] ?? null;
}
//# sourceMappingURL=user.repository.js.map