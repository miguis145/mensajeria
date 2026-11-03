import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/users_api.dart';
import '../../core/chat/chat_controller.dart';
import '../../core/audio/audio_recorder_service.dart';
import '../../core/audio/audio_player_service.dart';
import '../../models/chat_message.dart';

import 'package:flutter/services.dart';

class ChatScreen extends StatefulWidget {
  final FamilyUser peer;
  const ChatScreen({super.key, required this.peer});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _recorder = AudioRecorderService();
  final _player = AudioPlayerService();

  bool _isRecording = false;
  String? _recordingPath;
  String? _playingMessageId;

  @override
  void dispose() {
    _textController.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  void _showNotSent() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sin conexión: el mensaje no se envió')),
    );
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final sent = context.read<ChatController>().sendText(widget.peer, text);
    if (sent) {
      _textController.clear();
    } else {
      _showNotSent(); // conservamos el texto para que pueda reintentar
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Necesitas dar permiso de micrófono')),
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.startRecording(_recordingPath!);
    setState(() => _isRecording = true);
  }

  Future<void> _stopAndSend() async {
    if (!_isRecording) return;
    setState(() => _isRecording = false);

    final audioBytes = await _recorder.stopRecording();
    if (audioBytes == null || audioBytes.isEmpty) return;

    if (mounted) {
      final sent = context.read<ChatController>().sendAudio(
        widget.peer,
        audioBytes,
      );
      if (!sent) _showNotSent();
    }
  }

  void _cancelRecording() {
    setState(() => _isRecording = false);
    _recorder.stopRecording(); // descarta el resultado, no lo enviamos
  }

  Future<void> _togglePlay(ChatMessage msg) async {
    if (msg.audioBytes == null) return;

    if (_playingMessageId == msg.id) {
      await _player.stop();
      setState(() => _playingMessageId = null);
    } else {
      setState(() => _playingMessageId = msg.id);
      await _player.playBytes(msg.audioBytes!, msg.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    final messages = chat.messagesWith(widget.peer.id);

    return Scaffold(
      appBar: AppBar(title: Text(widget.peer.username)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[messages.length - 1 - index];
                return Align(
                  alignment: msg.isMine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: msg.isMine
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: msg.type == 'audio'
                        ? _AudioBubble(
                            isPlaying: _playingMessageId == msg.id,
                            onTap: () => _togglePlay(msg),
                          )
                        : Text(msg.plaintext),
                  ),
                );
              },
            ),
          ),
          if (_isRecording)
            Container(
              color: Colors.red.shade50,
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mic, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text(
                    'Grabando... suelta para enviar, desliza para cancelar',
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(hintText: 'Mensaje...'),
                    onSubmitted: (_) => _sendText(),
                    enabled: !_isRecording,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isRecording ? null : _sendText,
                ),
                GestureDetector(
                  onLongPressStart: (_) {
                    HapticFeedback.mediumImpact(); // vibración al empezar a grabar
                    _startRecording();
                  },
                  onLongPressEnd: (_) => _stopAndSend(),
                  onLongPressCancel: _cancelRecording,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _isRecording ? 64 : 48,
                    height: _isRecording ? 64 : 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                    ),
                    child: Icon(
                      _isRecording ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioBubble extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _AudioBubble({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
          const SizedBox(width: 8),
          const Text('Nota de voz'),
        ],
      ),
    );
  }
}
