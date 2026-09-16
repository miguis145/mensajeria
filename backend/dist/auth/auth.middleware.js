import { verifyToken } from './auth.service.js';
export function requireAuth(req, res, next) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        res.status(401).json({ error: 'Falta el token de autenticación' });
        return;
    }
    const token = authHeader.slice('Bearer '.length);
    try {
        const payload = verifyToken(token);
        req.user = payload;
        next();
    }
    catch {
        res.status(401).json({ error: 'Token inválido o expirado' });
    }
}
//# sourceMappingURL=auth.middleware.js.map