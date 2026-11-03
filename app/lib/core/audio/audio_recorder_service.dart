import 'dart:typed_data';

import 'package:record/record.dart';

import 'dart:io';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> startRecording(String filePath) async {
    if (!await hasPermission()) {
      throw Exception('Permiso de micrófono denegado');
    }
    await _recorder.start(const RecordConfig(), path: filePath);
  }

  /// Detiene la grabación y devuelve los bytes del audio grabado.
  Future<Uint8List?> stopRecording() async {
    final path = await _recorder.stop();
    if (path == null) return null;

    final file = File(path);
    return file.readAsBytes();
  }

  Future<void> dispose() => _recorder.dispose();
}
