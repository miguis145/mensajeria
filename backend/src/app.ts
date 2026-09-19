import express from 'express';
import { registerHandler, loginHandler } from './auth/auth.controller.js';
import { requireAuth } from './auth/auth.middleware.js';
import { messageService } from './messaging/message.service.js';

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
