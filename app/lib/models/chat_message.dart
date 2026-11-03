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

  /// Copia el mensaje cambiando solo lo indicado. Se usa cuando el servidor
  /// confirma un envío: el id local pasa a ser el real y la caducidad la real.
  ChatMessage copyWith({String? id, DateTime? sentAt, DateTime? expiresAt}) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId,
      type: type,
      plaintext: plaintext,
      sentAt: sentAt ?? this.sentAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isMine: isMine,
      audioBytes: audioBytes,
    );
  }
}
