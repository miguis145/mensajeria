import { describe, it, expect } from 'vitest';
import { AudioService } from './audio.service';

describe('AudioService.validateAudioPayload', () => {
  const service = new AudioService();

  it('acepta un audio válido dentro del límite de tamaño', () => {
    const audioFalso = Buffer.alloc(1024, 'a').toString('base64'); // 1KB
    expect(service.validateAudioPayload(audioFalso)).toBe(true);
  });

  it('rechaza un audio vacío', () => {
    const vacio = Buffer.alloc(0).toString('base64');
    expect(() => service.validateAudioPayload(vacio)).toThrow('vacío');
  });

  it('rechaza un audio que excede el tamaño máximo (10MB)', () => {
    const grande = Buffer.alloc(11 * 1024 * 1024).toString('base64'); // 11MB
    expect(() => service.validateAudioPayload(grande)).toThrow('excede el tamaño máximo');
  });

  it('acepta un audio justo en el límite de 10MB', () => {
    const limite = Buffer.alloc(10 * 1024 * 1024).toString('base64');
    expect(service.validateAudioPayload(limite)).toBe(true);
  });
});

describe('AudioService.processAudioBuffer', () => {
  const service = new AudioService();

  it('decodifica correctamente el base64 a Buffer', () => {
    const original = 'contenido-de-audio-simulado';
    const base64 = Buffer.from(original).toString('base64');

    const resultado = service.processAudioBuffer(base64);

    expect(resultado).toBeInstanceOf(Buffer);
    expect(resultado.toString()).toBe(original);
  });

  it('lanza error si el audio está vacío (delegando la validación)', () => {
    const vacio = Buffer.alloc(0).toString('base64');
    expect(() => service.processAudioBuffer(vacio)).toThrow();
  });
});