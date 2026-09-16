import express from 'express';
import { registerHandler, loginHandler } from './auth/auth.controller.js';
import { requireAuth } from './auth/auth.middleware.js';
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
//# sourceMappingURL=app.js.map