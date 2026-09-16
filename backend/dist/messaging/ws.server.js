import { WebSocketServer, WebSocket } from 'ws';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { messageService } from './message.service.js';
export function initWebSocketServer(server) {
    const wss = new WebSocketServer({ server });
    const activeUsers = new Map();
    wss.on('connection', (ws, req) => {
        ws.isAlive = true;
        // Autenticación vía query param ?token=... o mensaje inicial
        const url = new URL(req.url ?? '', `http://${req.headers.host}`);
        const token = url.searchParams.get('token');
        if (token) {
            try {
                const decoded = jwt.verify(token, env.jwtSecret);
                ws.userId = decoded.sub;
                activeUsers.set(ws.userId, ws);
            }
            catch {
                ws.close(4001, 'Token inválido');
                return;
            }
        }
        ws.on('message', async (data) => {
            try {
                const message = JSON.parse(data.toString());
                if (message.type === 'auth') {
                    const decoded = jwt.verify(message.token, env.jwtSecret);
                    ws.userId = decoded.sub;
                    activeUsers.set(ws.userId, ws);
                    ws.send(JSON.stringify({ type: 'auth_success' }));
                    return;
                }
                if (!ws.userId) {
                    ws.send(JSON.stringify({ type: 'error', message: 'No autenticado' }));
                    return;
                }
                if (message.type === 'send_message') {
                    const payload = message.payload;
                    const savedMessage = await messageService.send(ws.userId, payload);
                    // Confirmar recepción al emisor
                    ws.send(JSON.stringify({
                        type: 'message_sent',
                        payload: { id: savedMessage.id, sent_at: savedMessage.sent_at }
                    }));
                    // Notificar al receptor si está conectado
                    const recipientSocket = activeUsers.get(payload.receiverId);
                    if (recipientSocket && recipientSocket.readyState === WebSocket.OPEN) {
                        recipientSocket.send(JSON.stringify({
                            type: 'new_message',
                            payload: {
                                id: savedMessage.id,
                                senderId: savedMessage.sender_id,
                                type: savedMessage.type,
                                ciphertext: savedMessage.ciphertext.toString('base64'),
                                nonce: savedMessage.nonce.toString('base64'),
                                audioBlob: savedMessage.audio_blob?.toString('base64'),
                                sent_at: savedMessage.sent_at,
                                expires_at: savedMessage.expires_at,
                            }
                        }));
                        await messageService.markDelivered(savedMessage.id);
                    }
                }
                if (message.type === 'mark_read') {
                    await messageService.markRead(message.messageId);
                }
            }
            catch (err) {
                ws.send(JSON.stringify({ type: 'error', message: err.message }));
            }
        });
        ws.on('close', () => {
            if (ws.userId) {
                activeUsers.delete(ws.userId);
            }
        });
    });
    return wss;
}
//# sourceMappingURL=ws.server.js.map