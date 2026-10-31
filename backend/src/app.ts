import express from 'express';
import { registerHandler, loginHandler } from './auth/auth.controller.js';
import { requireAuth } from './auth/auth.middleware.js';
import { messageService } from './messaging/message.service.js';
import {  listUsersExcept, findUserById,  updateDefaultExpiry,} from './auth/user.repository.js';

export const app = express();

app.use(express.json());

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.post('/auth/register', registerHandler);
app.post('/auth/login', loginHandler);

// Ruta de ejemplo protegida, para confirmar que el middleware funciona
// conectado al servidor real, no solo en tests aislados.
app.get('/auth/me', requireAuth, (req, res) => {
  res.status(200).json({ user: req.user });
});

app.get('/messages', requireAuth, async (req, res) => {
  try {
    if (!req.user) {
      res.status(401).json({ error: 'No autenticado' });
      return;
    }
    const messages = await messageService.getConversation(req.user.userId);
    res.status(200).json({ messages });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
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
  } catch (err: any) {
    res.status(500).json({ error: err.message });
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
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

app.patch('/settings', requireAuth, async (req, res) => {
  try {
    if (!req.user) {
      res.status(401).json({ error: 'No autenticado' });
      return;
    }

    const { defaultExpirySeconds } = req.body;

    if (
      typeof defaultExpirySeconds !== 'number' ||
      defaultExpirySeconds < MIN_EXPIRY_SECONDS ||
      defaultExpirySeconds > MAX_EXPIRY_SECONDS
    ) {
      res.status(400).json({
        error: `defaultExpirySeconds debe ser un número entre ${MIN_EXPIRY_SECONDS} y ${MAX_EXPIRY_SECONDS}`,
      });
      return;
    }

    const updated = await updateDefaultExpiry(req.user.userId, defaultExpirySeconds);
    res.status(200).json({
      defaultExpirySeconds: updated.default_expiry_seconds,
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});