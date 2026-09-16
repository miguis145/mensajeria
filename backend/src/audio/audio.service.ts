export class AudioService {
  // Límite recomendado para notas de voz en base64/buffer (ej. 10MB)
  private readonly MAX_AUDIO_SIZE_BYTES = 10 * 1024 * 1024;

  validateAudioPayload(audioBase64: string): boolean {
    const buffer = Buffer.from(audioBase64, 'base64');
    if (buffer.length === 0) {
      throw new Error('El archivo de audio está vacío.');
    }
    if (buffer.length > this.MAX_AUDIO_SIZE_BYTES) {
      throw new Error('El archivo de audio excede el tamaño máximo permitido (10MB).');
    }
    return true;
  }

  processAudioBuffer(audioBase64: string): Buffer {
    this.validateAudioPayload(audioBase64);
    return Buffer.from(audioBase64, 'base64');
  }
}

export const audioService = new AudioService();a