import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  /// Se emite cuando el audio llega al final (para volver el botón a "play").
  Stream<void> get onCompleted => _player.processingStateStream.where(
    (s) => s == ProcessingState.completed,
  );

  /// Avance de la reproducción entre 0.0 y 1.0 (para pintar la onda).
  Stream<double> get progress => _player.positionStream.map((position) {
    final total = _player.duration;
    if (total == null || total.inMilliseconds == 0) return 0.0;
    return (position.inMilliseconds / total.inMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  });

  Future<void> playBytes(Uint8List audioBytes, String messageId) async {
    final dir = await getTemporaryDirectory();
    final tempFile = File('${dir.path}/audio_$messageId.m4a');
    await tempFile.writeAsBytes(audioBytes);

    await _player.setFilePath(tempFile.path);
    await _player.play();
  }

  Future<void> stop() => _player.stop();
  Future<void> dispose() => _player.dispose();
}
