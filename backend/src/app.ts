import express from 'express';
import type { Response } from 'express';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { registerHandler, loginHandler } from './auth/auth.controller.js';
import { requireAuth } from './auth/auth.middleware.js';
import { messageService } from './messaging/message.service.js';
import { toWireMessage } from './messaging/wire.js';
import { listUsersExcept, findUserById, updateDefaultExpiry } from './auth/user.repository.js';

export const app = express();

app.use(helmet());
// Registro, login y ajustes son JSON pequeños: 100 KB sobran y frenan abusos
app.use(express.json({ limit: '100kb' }));

// Freno a la fuerza bruta: 20 intentos de login/registro cada 15 min por IP
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { error: 'Demasiados intentos, espera unos minutos' },
});

/** El detalle del error queda en el log del servidor; al cliente solo "Error interno". */
function internalError(res: Response, route: string, err: unknown): void {
  console.error(`[${route}]`, err);
  res.status(500).json({ error: 'Error interno' });
}

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.post('/auth/register', authLimiter, registerHandler);
app.post('/auth/login', authLimiter, loginHandler);

// Ruta de ejemplo protegida, para confirmar que el middleware funciona
// conectado al servidor real, no solo en tests aislados.
app.get('/auth/me', requireAuth, (req, res) => {
  res.status(200).json({ user: req.user });
});

// Mensajes pendientes: solo los de este usuario y solo mientras NO haya vencido
// SU copia. Mismo formato que "new_message" del WebSocket (Buffers en base64).
app.get('/messages', requireAuth, async (req, res) => {
  try {
    if (!req.user) {
      res.status(401).json({ error: 'No autenticado' });
      return;
    }
    const rows = await messageService.getConversation(req.user.userId);
    res.status(200).json({ messages: rows.map((r) => toWireMessage(r, req.user!.userId)) });
  } catch (err) {
    internalError(res, 'GET /messages', err);
  }
});

app.get('/users', requireAuth, async (req, res) => {
  try {
    if (!req.user) {
      res.status(401).json({ error: 'No autenticado' });
      return;
    }
    const users = await listUsersExcept(req.user.userId);
    res.status(200).json({
      users: users.map((u) => ({
        id: u.id,
        username: u.username,
        publicKey: u.public_key.toString('base64'),
      })),
    });
  } catch (err) {
    internalError(res, 'GET /users', err);
  }
});

const MIN_EXPIRY_SECONDS = 60; // 1 minuto
const MAX_EXPIRY_SECONDS = 30 * 24 * 60 * 60; // 30 días

app.get('/settings', requireAuth, async (req, res) => {
  try {
    if (!req.user) {
      res.status(401).json({ error: 'No autenticado' });
      return;
    }
    const user = await findUserById(req.user.userId);
    if (!user) {
      res.status(404).json({ error: 'Usuario no encontrado' });
      return;
    }
    res.status(200).json({
      defaultExpirySeconds: user.default_expiry_seconds,
    });
  } catch (err) {
    internalError(res, 'GET /settings', err);
  }
});

app.patch('/settings', requireAuth, async (req, res) => {
  try {
    if (!req.user) {
      res.status(401).json({ error: 'No autenticado' });
      return;
    }

    const { defaultExpirySeconds } = req.body ?? {};

    if (
      typeof defaultExpirySeconds !== 'number' ||
      !Number.isInteger(defaultExpirySeconds) ||
      defaultExpirySeconds < MIN_EXPIRY_SECONDS ||
      defaultExpirySeconds > MAX_EXPIRY_SECONDS
    ) {
      res.status(400).json({
        error: `defaultExpirySeconds debe ser un entero entre ${MIN_EXPIRY_SECONDS} y ${MAX_EXPIRY_SECONDS}`,
      });
      return;
    }

    const updated = await updateDefaultExpiry(req.user.userId, defaultExpirySeconds);
    res.status(200).json({
      defaultExpirySeconds: updated.default_expiry_seconds,
    });
  } catch (err) {
    internalError(res, 'PATCH /settings', err);
  }
});
