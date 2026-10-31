import 'dart:typed_data';

class ChatMessage {
  final String id;
  final String senderId;
  final String type; // 'text' | 'audio'
  final String plaintext;
  final DateTime sentAt;
  final DateTime expiresAt;
  final bool isMine;
  final Uint8List? audioBytes;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.type,
    required this.plaintext,
    required this.sentAt,
    required this.expiresAt,
    required this.isMine,
    this.audioBytes,
  });
}