// src/index.ts
import { app } from './app.js';
import { env } from './config/env.js';
import { checkDatabaseConnection } from './db/client.js';

async function main() {
  await checkDatabaseConnection();
  console.log('✓ Conexión a la base de datos verificada');

  app.listen(env.port, () => {
    console.log(`✓ Servidor corriendo en http://localhost:${env.port}`);
  });
}

main().catch((err) => {
  console.error('Error al arrancar el servidor:', err);
  process.exit(1);
});