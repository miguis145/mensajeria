import pg from 'pg';
import { env } from '../config/env.js';
const { Pool } = pg;
export const pool = new Pool({
    connectionString: env.databaseUrl,
});
export async function checkDatabaseConnection() {
    const client = await pool.connect();
    try {
        await client.query('SELECT 1');
    }
    finally {
        client.release();
    }
}
//# sourceMappingURL=client.js.map