import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../crypto/crypto_service.dart';
import '../storage/secure_storage_service.dart';
import '../api/users_api.dart';
import '../api/messages_api.dart';
import '../api/chat_websocket.dart';
import '../../models/chat_message.dart';

class ChatController extends ChangeNotifier {
  final CryptoService _crypto;
  final SecureStorageService _storage;
  final UsersApi _usersApi;
  final MessagesApi _messagesApi;
  final ChatWebSocket _ws;

  ChatController({
    required CryptoService crypto,
    required SecureStorageService storage,
    required UsersApi usersApi,
    required MessagesApi messagesApi,
    required ChatWebSocket ws,
  }) : _crypto = crypto,
       _storage = storage,
       _usersApi = usersApi,
       _messagesApi = messagesApi,
       _ws = ws;

  /// Un mensaje que el servidor no confirma en este tiempo se descarta de la
  /// pantalla: así nunca queda mostrado como "enviado" algo que no llegó.
  static const _unconfirmedTtl = Duration(seconds: 60);

  List<FamilyUser> familyUsers = [];
  final Map<String, List<ChatMessage>> _conversations = {};
  ConnectionStatus connectionStatus = ConnectionStatus.connecting;
  String? _myUserId;
  String? _token;
  dynamic _myPrivateKey; // SecureKey

  Timer? _expiryTimer;
  StreamSubscription<ConnectionStatus>? _statusSub;
  StreamSubscription<Map<String, dynamic>>? _messagesSub;
  int _clientCounter = 0;
  bool _syncing = false;

  /// Mensajes de la conversación, sin los que ya caducaron en ESTE dispositivo.
  List<ChatMessage> messagesWith(String peerId) {
    final now = DateTime.now();
    return (_conversations[peerId] ?? [])
        .where((m) => m.expiresAt.isAfter(now))
        .toList(growable: false);
  }

  Future<void> init({required String token, required String myUserId}) async {
    _myUserId = myUserId;
    _token = token;

    final privBytes = await _storage.getPrivateKey();
    if (privBytes == null) {
      throw Exception('No hay clave privada guardada en este dispositivo');
    }
    _myPrivateKey = _crypto.loadPrivateKey(privBytes);

    familyUsers = await _usersApi.listUsers(token);

    // Nos suscribimos ANTES de conectar para no perder ningún evento.
    _messagesSub = _ws.messages.listen(_handleIncoming);
    _statusSub = _ws.status.listen((s) {
      final wasConnected = connectionStatus == ConnectionStatus.connected;
      connectionStatus = s;
      notifyListeners();
      // Cada vez que (re)conectamos pedimos lo que llegó mientras no estábamos.
      if (s == ConnectionStatus.connected && !wasConnected) {
        _syncPending();
      }
    });

    await _ws.connect(token);

    // Revisa cada pocos segundos qué mensajes ya caducaron y los borra de memoria.
    _expiryTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _purgeExpired(),
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------- recepción

  void _handleIncoming(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'new_message':
        _storeFromServer(data['payload'] as Map<String, dynamic>);
        break;
      case 'message_sent':
        _confirmSent(data['payload'] as Map<String, dynamic>);
        break;
      case 'error':
        debugPrint('Error del servidor: ${data['message']}');
        break;
    }
  }

  /// Descarga los mensajes pendientes y los descifra. Es seguro llamarla varias
  /// veces: los mensajes ya conocidos se ignoran (se comparan por id).
  Future<void> _syncPending() async {
    final token = _token;
    if (token == null || _syncing) return;
    _syncing = true;
    try {
      familyUsers = await _usersApi.listUsers(
        token,
      ); // por si hay familiares nuevos
      final pending = await _messagesApi.listMessages(token);
      for (final payload in pending) {
        await _storeFromServer(payload, notify: false);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('No se pudieron sincronizar los mensajes pendientes: $e');
    } finally {
      _syncing = false;
    }
  }

  FamilyUser? _findUser(String id) {
    for (final u in familyUsers) {
      if (u.id == id) return u;
    }
    return null;
  }

  /// Descifra un mensaje del servidor (recibido o enviado por mí) y lo guarda.
  ///
  /// crypto_box usa un secreto compartido entre mi clave privada y la clave
  /// pública de la OTRA persona, y ese secreto es el mismo en ambos sentidos.
  /// Por eso también puedo descifrar mis propios mensajes enviados.
  Future<void> _storeFromServer(
    Map<String, dynamic> payload, {
    bool notify = true,
  }) async {
    try {
      final senderId = payload['senderId'] as String;
      final receiverId = payload['receiverId'] as String;
      final isMine = senderId == _myUserId;
      final peerId = isMine ? receiverId : senderId;
      final id = payload['id'] as String;

      final expiresAt = DateTime.parse(payload['expires_at'] as String);
      if (!expiresAt.isAfter(DateTime.now())) return; // ya caducó para mí
      if (_hasMessage(peerId, id)) return; // ya lo tenía

      var peer = _findUser(peerId);
      if (peer == null && _token != null) {
        familyUsers = await _usersApi.listUsers(_token!);
        peer = _findUser(peerId);
      }
      if (peer == null) {
        debugPrint('Mensaje de un usuario desconocido: $peerId');
        return;
      }

      final plaintextBytes = _crypto.decryptMessage(
        ciphertext: base64Decode(payload['ciphertext'] as String),
        nonce: base64Decode(payload['nonce'] as String),
        senderPublicKey: base64Decode(
          peer.publicKeyBase64,
        ), // clave de la OTRA persona
        receiverPrivateKey: _myPrivateKey,
      );

      final type = payload['type'] as String;
      _addMessage(
        peerId,
        ChatMessage(
          id: id,
          senderId: senderId,
          type: type,
          plaintext: type == 'text'
              ? _crypto.bytesToString(plaintextBytes)
              : '[Nota de voz]',
          sentAt: DateTime.parse(payload['sent_at'] as String),
          expiresAt: expiresAt,
          isMine: isMine,
          audioBytes: type == 'audio' ? plaintextBytes : null,
        ),
      );
      if (notify) notifyListeners();
    } catch (e) {
      // Un mensaje que no se puede descifrar no debe impedir ver los demás.
      debugPrint('No se pudo procesar un mensaje: $e');
    }
  }

  bool _hasMessage(String peerId, String id) =>
      (_conversations[peerId] ?? const []).any((m) => m.id == id);

  void _addMessage(String peerId, ChatMessage message) {
    final list = _conversations.putIfAbsent(peerId, () => []);
    list.add(message);
    list.sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  // ------------------------------------------------------------------- envío

  String _newClientId() =>
      'c${DateTime.now().microsecondsSinceEpoch}-${_clientCounter++}';

  /// El servidor confirma un envío: cambiamos el id local por el real y usamos
  /// la fecha de caducidad que le corresponde a MI copia del mensaje.
  void _confirmSent(Map<String, dynamic> payload) {
    final clientId = payload['clientId'] as String?;
    final serverId = payload['id'] as String;
    if (clientId == null) return;

    for (final list in _conversations.values) {
      final index = list.indexWhere((m) => m.id == clientId);
      if (index == -1) continue;

      if (list.any((m) => m.id == serverId)) {
        // La sincronización ya había traído este mensaje: quitamos el duplicado local.
        list.removeAt(index);
      } else {
        list[index] = list[index].copyWith(
          id: serverId,
          sentAt: DateTime.parse(payload['sent_at'] as String),
          expiresAt: DateTime.parse(payload['expires_at'] as String),
        );
      }
      notifyListeners();
      return;
    }
  }

  /// Devuelve false si no se pudo enviar (por ejemplo, sin conexión).
  bool sendText(FamilyUser peer, String text) {
    return _send(
      peer: peer,
      type: 'text',
      plainBytes: _crypto.stringToBytes(text),
      plaintext: text,
    );
  }

  /// Devuelve false si no se pudo enviar (por ejemplo, sin conexión).
  bool sendAudio(FamilyUser peer, Uint8List audioBytes) {
    return _send(
      peer: peer,
      type: 'audio',
      plainBytes: audioBytes,
      plaintext: '[Nota de voz]',
      audioBytes: audioBytes,
    );
  }

  bool _send({
    required FamilyUser peer,
    required String type,
    required Uint8List plainBytes,
    required String plaintext,
    Uint8List? audioBytes,
  }) {
    if (!_ws.isConnected) return false;

    final encrypted = _crypto.encryptMessage(
      message: plainBytes,
      receiverPublicKey: base64Decode(peer.publicKeyBase64),
      senderPrivateKey: _myPrivateKey,
    );

    final clientId = _newClientId();
    final sent = _ws.sendMessage(
      receiverId: peer.id,
      type: type,
      ciphertextBase64: base64Encode(encrypted.ciphertext),
      nonceBase64: base64Encode(encrypted.nonce),
      clientId: clientId,
    );
    if (!sent) return false;

    // Mensaje provisional: se muestra ya, y cuando el servidor confirme se le
    // pone su id y su caducidad reales (ver _confirmSent).
    final now = DateTime.now();
    _addMessage(
      peer.id,
      ChatMessage(
        id: clientId,
        senderId: _myUserId!,
        type: type,
        plaintext: plaintext,
        sentAt: now,
        expiresAt: now.add(_unconfirmedTtl),
        isMine: true,
        audioBytes: audioBytes,
      ),
    );
    notifyListeners();
    return true;
  }

  // -------------------------------------------------------------- caducidad

  void _purgeExpired() {
    final now = DateTime.now();
    var changed = false;
    for (final list in _conversations.values) {
      final before = list.length;
      list.removeWhere((m) => !m.expiresAt.isAfter(now));
      if (list.length != before) changed = true;
    }
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _statusSub?.cancel();
    _messagesSub?.cancel();
    _ws.dispose();
    super.dispose();
  }
}
