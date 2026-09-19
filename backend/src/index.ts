import { app } from './app.js';
import http from 'node:http';
import { env } from './config/env.js';
import { checkDatabaseConnection } from './db/client.js';
import { initWebSocketServer } from './messaging/ws.server.js';
import { startExpiryWorker } from './expiry/expiry.worker.js';

async function main() {
  await checkDatabaseConnection();
  console.log('✓ Conexión a la base de datos verificada');


  const server = http.createServer(app);

  initWebSocketServer(server);
  startExpiryWorker();

  server.listen(env.port, () => {
    console.log(`✓ Servidor corriendo en http://localhost:${env.port}`);
    console.log(`Servidor HTTP y WebSocket escuchando en el puerto ${env.port}`);
  });
}

main().catch((err) => {
  console.error('Error al arrancar el servidor:', err);
  process.exit(1);
});