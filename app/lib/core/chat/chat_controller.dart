import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../crypto/crypto_service.dart';
import '../storage/secure_storage_service.dart';
import '../api/users_api.dart';
import '../api/chat_websocket.dart';
import '../../models/chat_message.dart';

class ChatController extends ChangeNotifier {
  final CryptoService _crypto;
  final SecureStorageService _storage;
  final UsersApi _usersApi;
  final ChatWebSocket _ws;

  ChatController({
    required CryptoService crypto,
    required SecureStorageService storage,
    required UsersApi usersApi,
    required ChatWebSocket ws,
  })  : _crypto = crypto,
        _storage = storage,
        _usersApi = usersApi,
        _ws = ws;

  List<FamilyUser> familyUsers = [];
  final Map<String, List<ChatMessage>> _conversations = {};
  ConnectionStatus connectionStatus = ConnectionStatus.connecting;
  String? _myUserId;
  dynamic _myPrivateKey; // SecureKey

  List<ChatMessage> messagesWith(String peerId) =>
      List.unmodifiable(_conversations[peerId] ?? []);

  Future<void> init({required String token, required String myUserId}) async {
    _myUserId = myUserId;

    final privBytes = await _storage.getPrivateKey();
    if (privBytes == null) {
      throw Exception('No hay clave privada guardada en este dispositivo');
    }
    _myPrivateKey = _crypto.loadPrivateKey(privBytes);

    familyUsers = await _usersApi.listUsers(token);

    _ws.status.listen((s) {
      connectionStatus = s;
      notifyListeners();
    });

    await _ws.connect(token);
    _ws.messages.listen(_handleIncoming);

    notifyListeners();
  }

  void _handleIncoming(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'new_message':
        _decryptAndStore(data['payload'], isMine: false);
        break;
      case 'error':
        debugPrint('Error del servidor: ${data['message']}');
        break;
    }
  }

  void _decryptAndStore(Map<String, dynamic> payload, {required bool isMine}) {
    final senderId = payload['senderId'] as String;
    final peer = familyUsers.firstWhere(
      (u) => u.id == senderId,
      orElse: () => throw Exception('Usuario desconocido: $senderId'),
    );

    final ciphertext = base64Decode(payload['ciphertext']);
    final nonce = base64Decode(payload['nonce']);
    final senderPublicKey = base64Decode(peer.publicKeyBase64);

    final plaintextBytes = _crypto.decryptMessage(
      ciphertext: ciphertext,
      nonce: nonce,
      senderPublicKey: senderPublicKey,
      receiverPrivateKey: _myPrivateKey,
    );

    final type = payload['type'] as String;
    final message = ChatMessage(
      id: payload['id'],
      senderId: senderId,
      type: type,
      plaintext: type == 'text' ? _crypto.bytesToString(plaintextBytes) : '[Nota de voz]',
      sentAt: DateTime.parse(payload['sent_at']),
      expiresAt: DateTime.parse(payload['expires_at']),
      isMine: isMine,
      audioBytes: type == 'audio' ? plaintextBytes : null,
    );

    _conversations.putIfAbsent(senderId, () => []).add(message);
    notifyListeners();
  }

  void sendText(FamilyUser peer, String text) {
    final receiverPublicKey = base64Decode(peer.publicKeyBase64);

    final encrypted = _crypto.encryptMessage(
      message: _crypto.stringToBytes(text),
      receiverPublicKey: receiverPublicKey,
      senderPrivateKey: _myPrivateKey,
    );

    _ws.sendMessage(
      receiverId: peer.id,
      type: 'text',
      ciphertextBase64: base64Encode(encrypted.ciphertext),
      nonceBase64: base64Encode(encrypted.nonce),
    );

    final localMessage = ChatMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      senderId: _myUserId!,
      type: 'text',
      plaintext: text,
      sentAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      isMine: true,
    );
    _conversations.putIfAbsent(peer.id, () => []).add(localMessage);
    notifyListeners();
  }

  void sendAudio(FamilyUser peer, Uint8List audioBytes) {
    final receiverPublicKey = base64Decode(peer.publicKeyBase64);

    final encrypted = _crypto.encryptMessage(
      message: audioBytes,
      receiverPublicKey: receiverPublicKey,
      senderPrivateKey: _myPrivateKey,
    );

    _ws.sendMessage(
      receiverId: peer.id,
      type: 'audio',
      ciphertextBase64: base64Encode(encrypted.ciphertext),
      nonceBase64: base64Encode(encrypted.nonce),
    );

    final localMessage = ChatMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      senderId: _myUserId!,
      type: 'audio',
      plaintext: '[Nota de voz]',
      sentAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      isMine: true,
      audioBytes: audioBytes,
    );
    _conversations.putIfAbsent(peer.id, () => []).add(localMessage);
    notifyListeners();
  }

  @override
  void dispose() {
    _ws.dispose();
    super.dispose();
  }
}