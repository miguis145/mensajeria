import { readdir, readFile } from 'fs/promises';
import { fileURLToPath } from 'url';
import path from 'path';
import { pool } from './client.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const MIGRATIONS_DIR = path.join(__dirname, 'migrations');

async function runMigrations(): Promise<void> {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS _migrations (
      name TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  const files = (await readdir(MIGRATIONS_DIR)).sort();
  const { rows: applied } = await pool.query<{ name: string }>(
    'SELECT name FROM _migrations'
  );
  const appliedNames = new Set(applied.map((r) => r.name));

  for (const file of files) {
    if (appliedNames.has(file)) {
      console.log(`↷ Ya aplicada: ${file}`);
      continue;
    }

    const sql = await readFile(path.join(MIGRATIONS_DIR, file), 'utf-8');
    console.log(`▶ Aplicando: ${file}`);

    await pool.query(sql);
    await pool.query('INSERT INTO _migrations (name) VALUES ($1)', [file]);
  }

  console.log('✓ Migraciones al día');
}

runMigrations()
  .then(() => pool.end())
  .catch((err) => {
    console.error('Error aplicando migraciones:', err);
    process.exit(1);
  });