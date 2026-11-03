import { WebSocketServer, WebSocket } from 'ws';
import type { Server } from 'node:http';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { messageService } from './message.service.js';
import { validateSendMessage, extractClientId } from './validation.js';
import { toWireMessage } from './wire.js';
import { AppError } from '../shared/errors.js';

interface AuthenticatedSocket extends WebSocket {
  userId?: string;
  isAlive?: boolean;
}

// 10 MB de audio en base64 son ~13.4 MB; dejamos margen para el JSON.
const MAX_PAYLOAD_BYTES = 15 * 1024 * 1024;
const AUTH_TIMEOUT_MS = 10_000;
const PING_INTERVAL_MS = 30_000;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function initWebSocketServer(server: Server) {
  // maxPayload: ws cierra la conexión si un mensaje excede este tamaño,
  // antes de que lleguemos a hacer JSON.parse con él en memoria.
  const wss = new WebSocketServer({ server, maxPayload: MAX_PAYLOAD_BYTES });
  const activeUsers = new Map<string, AuthenticatedSocket>();

  function authenticate(ws: AuthenticatedSocket, token: string): void {
    const decoded = jwt.verify(token, env.jwtSecret) as { userId: string };
    ws.userId = decoded.userId;
    activeUsers.set(ws.userId, ws);
  }

  function sendError(ws: WebSocket, message: string): void {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'error', message }));
    }
  }

  wss.on('connection', (ws: AuthenticatedSocket, req) => {
    ws.isAlive = true;
    ws.on('pong', () => {
      ws.isAlive = true;
    });
    // Sin este manejador, un error del socket (p. ej. mensaje que excede
    // maxPayload) se vuelve una excepción no capturada y TUMBA el proceso.
    ws.on('error', (err) => {
      console.warn('[WS] Error de socket:', (err as Error).message);
    });

    // Autenticación vía query param ?token=... o mensaje inicial
    const url = new URL(req.url ?? '', `http://${req.headers.host ?? 'localhost'}`);
    const token = url.searchParams.get('token');

    if (token) {
      try {
        authenticate(ws, token);
      } catch {
        ws.close(4001, 'Token inválido');
        return;
      }
    }

    // Un socket que no se autentica en 10 s se cierra (evita conexiones zombi)
    const authTimer = setTimeout(() => {
      if (!ws.userId) ws.close(4002, 'Autenticación requerida');
    }, AUTH_TIMEOUT_MS);

    ws.on('message', async (data) => {
      try {
        const message = JSON.parse(data.toString());

        if (message.type === 'auth') {
          try {
            authenticate(ws, message.token);
          } catch {
            ws.close(4001, 'Token inválido');
            return;
          }
          ws.send(JSON.stringify({ type: 'auth_success' }));
          return;
        }

        if (!ws.userId) {
          sendError(ws, 'No autenticado');
          return;
        }

        if (message.type === 'send_message') {
          const dto = validateSendMessage(ws.userId, message.payload);
          const savedMessage = await messageService.send(ws.userId, dto);

          // Confirmar recepción al emisor (con SU caducidad y su clientId)
          ws.send(
            JSON.stringify({
              type: 'message_sent',
              payload: {
                id: savedMessage.id,
                clientId: extractClientId(message.payload),
                sent_at: savedMessage.sent_at,
                expires_at: savedMessage.sender_expires_at,
              },
            }),
          );

          // Notificar al receptor si está conectado (con la caducidad del RECEPTOR)
          const recipientSocket = activeUsers.get(dto.receiverId);
          if (recipientSocket && recipientSocket.readyState === WebSocket.OPEN) {
            recipientSocket.send(
              JSON.stringify({
                type: 'new_message',
                payload: toWireMessage(savedMessage, dto.receiverId),
              }),
            );
            await messageService.markDelivered(savedMessage.id);
          }
          return;
        }

        if (message.type === 'mark_read') {
          if (typeof message.messageId !== 'string' || !UUID_RE.test(message.messageId)) {
            throw new AppError('Campo inválido: messageId', 400);
          }
          // Pasamos ws.userId: solo el receptor puede marcarlo como leído
          await messageService.markRead(message.messageId, ws.userId);
        }
      } catch (err) {
        if (err instanceof AppError) {
          sendError(ws, err.message);
        } else {
          // Detalle solo en el log del servidor, nunca al cliente
          console.error('[WS] Error procesando mensaje:', err);
          sendError(ws, 'Error interno');
        }
      }
    });

    ws.on('close', () => {
      clearTimeout(authTimer);
      // Solo borramos la entrada si sigue siendo ESTE socket. Si el usuario ya
      // reconectó, el socket viejo no debe eliminar al nuevo.
      if (ws.userId && activeUsers.get(ws.userId) === ws) {
        activeUsers.delete(ws.userId);
      }
    });
  });

  // Heartbeat: detecta conexiones muertas (teléfono sin red) y las cierra
  const pingTimer = setInterval(() => {
    for (const client of wss.clients as Set<AuthenticatedSocket>) {
      if (client.isAlive === false) {
        client.terminate();
        continue;
      }
      client.isAlive = false;
      client.ping();
    }
  }, PING_INTERVAL_MS);
  wss.on('close', () => clearInterval(pingTimer));
  server.once('close', () => clearInterval(pingTimer));

  return wss;
}
