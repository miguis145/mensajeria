import type { SendMessageDTO } from '../shared/types.js';
import { AppError } from '../shared/errors.js';
import { audioService } from '../audio/audio.service.js';

export const MIN_EXPIRY_SECONDS = 60; // 1 minuto
export const MAX_EXPIRY_SECONDS = 2_592_000; // 30 días
export const NONCE_BYTES = 24; // crypto_box_NONCEBYTES
export const MAX_TEXT_CIPHERTEXT_BYTES = 16 * 1024; // 16 KB de texto cifrado

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const BASE64_RE = /^[A-Za-z0-9+/]+={0,2}$/;

function decodeBase64(value: unknown, field: string): Buffer {
  if (typeof value !== 'string' || value.length === 0 || !BASE64_RE.test(value)) {
    throw new AppError(`Campo inválido: ${field}`, 400);
  }
  return Buffer.from(value, 'base64');
}

/**
 * Nunca confiamos en lo que llega por el WebSocket: es JSON controlado por el
 * cliente. Aquí validamos forma, tipos y tamaños antes de tocar la base de datos.
 */
export function validateSendMessage(senderId: string, raw: unknown): SendMessageDTO {
  if (typeof raw !== 'object' || raw === null) {
    throw new AppError('Payload inválido', 400);
  }
  const p = raw as Record<string, unknown>;

  if (typeof p.receiverId !== 'string' || !UUID_RE.test(p.receiverId)) {
    throw new AppError('Campo inválido: receiverId', 400);
  }
  if (p.receiverId === senderId) {
    throw new AppError('No puedes enviarte mensajes a ti mismo', 400);
  }
  if (p.type !== 'text' && p.type !== 'audio') {
    throw new AppError('Campo inválido: type', 400);
  }

  const ciphertext = decodeBase64(p.ciphertext, 'ciphertext');
  if (p.type === 'text') {
    if (ciphertext.length > MAX_TEXT_CIPHERTEXT_BYTES) {
      throw new AppError('ciphertext demasiado grande', 413);
    }
  } else {
    // La app cifra el audio completo y lo envía en "ciphertext" (no en audioBlob).
    // Reutilizamos el límite de 10 MB que ya definimos en AudioService.
    try {
      audioService.validateAudioPayload(p.ciphertext as string);
    } catch (e: any) {
      throw new AppError(e.message, 413);
    }
  }

  const nonce = decodeBase64(p.nonce, 'nonce');
  if (nonce.length !== NONCE_BYTES) {
    throw new AppError('Campo inválido: nonce', 400);
  }

  // audioBlob es una columna heredada que ningún cliente usa: no la aceptamos
  if (p.audioBlob !== undefined && p.audioBlob !== null) {
    throw new AppError('Campo no permitido: audioBlob', 400);
  }

  let expirySeconds: number | undefined;
  if (p.expirySeconds !== undefined && p.expirySeconds !== null) {
    if (
      typeof p.expirySeconds !== 'number' ||
      !Number.isInteger(p.expirySeconds) ||
      p.expirySeconds < MIN_EXPIRY_SECONDS ||
      p.expirySeconds > MAX_EXPIRY_SECONDS
    ) {
      throw new AppError(
        `expirySeconds debe ser un entero entre ${MIN_EXPIRY_SECONDS} y ${MAX_EXPIRY_SECONDS}`,
        400,
      );
    }
    expirySeconds = p.expirySeconds;
  }

  return {
    receiverId: p.receiverId,
    type: p.type,
    ciphertext: p.ciphertext as string,
    nonce: p.nonce as string,
    expirySeconds,
  };
}

const CLIENT_ID_RE = /^[\w-]{1,64}$/;

/**
 * "clientId" es un identificador que genera la app para reconocer su mensaje
 * local cuando llega la confirmación. El servidor solo lo devuelve tal cual.
 */
export function extractClientId(raw: unknown): string | undefined {
  if (typeof raw !== 'object' || raw === null) return undefined;
  const id = (raw as Record<string, unknown>).clientId;
  return typeof id === 'string' && CLIENT_ID_RE.test(id) ? id : undefined;
}
