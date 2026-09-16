import { messageRepository } from '../messaging/message.repository.js';
export function startExpiryWorker(intervalMs = 60000) {
    setInterval(async () => {
        try {
            const deletedCount = await messageRepository.deleteExpiredMessages();
            if (deletedCount > 0) {
                console.log(`[Expiry Worker] Eliminados ${deletedCount} mensajes expirados.`);
            }
        }
        catch (err) {
            console.error('[Expiry Worker] Error purgando mensajes:', err);
        }
    }, intervalMs);
}
//# sourceMappingURL=expiry.worker.js.map