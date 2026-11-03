import { describe, it, expect } from 'vitest';
import { validateSendMessage, extractClientId } from './validation.js';

const SENDER = '11111111-1111-4111-8111-111111111111';
const RECEIVER = '22222222-2222-4222-8222-222222222222';
const nonce = Buffer.alloc(24, 7).toString('base64');
const ct = Buffer.from('hola cifrado').toString('base64');

const ok = () => ({ receiverId: RECEIVER, type: 'text', ciphertext: ct, nonce });

describe('validateSendMessage', () => {
  it('acepta un mensaje de texto válido', () => {
    const dto = validateSendMessage(SENDER, ok());
    expect(dto.receiverId).toBe(RECEIVER);
    expect(dto.audioBlob).toBeUndefined();
  });

  it('rechaza payload que no es objeto', () => {
    expect(() => validateSendMessage(SENDER, null)).toThrow();
    expect(() => validateSendMessage(SENDER, 'hola')).toThrow();
  });

  it('rechaza receiverId que no es UUID o es el propio emisor', () => {
    expect(() => validateSendMessage(SENDER, { ...ok(), receiverId: 'abc' })).toThrow(/receiverId/);
    expect(() => validateSendMessage(SENDER, { ...ok(), receiverId: SENDER })).toThrow(/ti mismo/);
  });

  it('rechaza type desconocido', () => {
    expect(() => validateSendMessage(SENDER, { ...ok(), type: 'video' })).toThrow(/type/);
  });

  it('rechaza nonce con longitud incorrecta', () => {
    const bad = Buffer.alloc(10).toString('base64');
    expect(() => validateSendMessage(SENDER, { ...ok(), nonce: bad })).toThrow(/nonce/);
  });

  it('rechaza base64 inválido', () => {
    expect(() => validateSendMessage(SENDER, { ...ok(), ciphertext: '***' })).toThrow(/ciphertext/);
  });

  it('rechaza texto cifrado demasiado grande', () => {
    const big = Buffer.alloc(17 * 1024, 1).toString('base64');
    expect(() => validateSendMessage(SENDER, { ...ok(), ciphertext: big })).toThrow(/grande/);
  });

  it('rechaza expirySeconds fuera de rango, negativo o no entero', () => {
    for (const bad of [-5, 0, 59, 2_592_001, 1.5, '3600', NaN]) {
      expect(() => validateSendMessage(SENDER, { ...ok(), expirySeconds: bad })).toThrow(/expirySeconds/);
    }
  });

  it('acepta expirySeconds en los límites', () => {
    expect(validateSendMessage(SENDER, { ...ok(), expirySeconds: 60 }).expirySeconds).toBe(60);
    expect(validateSendMessage(SENDER, { ...ok(), expirySeconds: 2_592_000 }).expirySeconds).toBe(2_592_000);
  });

  it('un audio viaja en "ciphertext" (como lo envía la app), sin audioBlob', () => {
    const audio = Buffer.alloc(200 * 1024, 5).toString('base64'); // 200 KB, mucho más que un texto
    const dto = validateSendMessage(SENDER, { ...ok(), type: 'audio', ciphertext: audio });
    expect(dto.type).toBe('audio');
    expect(dto.ciphertext).toBe(audio);
  });

  it('rechaza audioBlob: ningún cliente lo usa', () => {
    const blob = Buffer.from('x').toString('base64');
    expect(() => validateSendMessage(SENDER, { ...ok(), audioBlob: blob })).toThrow(/audioBlob/);
    expect(() => validateSendMessage(SENDER, { ...ok(), type: 'audio', audioBlob: blob })).toThrow(/audioBlob/);
  });

  it('rechaza audio de más de 10 MB', () => {
    const huge = Buffer.alloc(10 * 1024 * 1024 + 1, 1).toString('base64');
    expect(() => validateSendMessage(SENDER, { ...ok(), type: 'audio', ciphertext: huge })).toThrow(/10MB/);
  });
});

describe('extractClientId', () => {
  it('devuelve el clientId válido y descarta los raros', () => {
    expect(extractClientId({ clientId: 'local-1730000000000' })).toBe('local-1730000000000');
    expect(extractClientId({ clientId: 'con espacios' })).toBeUndefined();
    expect(extractClientId({ clientId: 'x'.repeat(65) })).toBeUndefined();
    expect(extractClientId({ clientId: 42 })).toBeUndefined();
    expect(extractClientId(null)).toBeUndefined();
  });
});
