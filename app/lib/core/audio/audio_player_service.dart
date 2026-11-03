import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

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
