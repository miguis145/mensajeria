import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionStatus { connecting, connected, disconnected, reconnecting }

class ChatWebSocket {
  final String wsUrl;
  WebSocketChannel? _channel;
  String? _lastToken;
  bool _manuallyDisconnected = false;
  int _reconnectAttempts = 0;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();

  ChatWebSocket({required this.wsUrl});

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<ConnectionStatus> get status => _statusController.stream;

  Future<void> connect(String token) async {
    _lastToken = token;
    _manuallyDisconnected = false;
    await _openConnection();
  }

  Future<void> _openConnection() async {
    _statusController.add(
      _reconnectAttempts == 0 ? ConnectionStatus.connecting : ConnectionStatus.reconnecting,
    );

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready; // lanza si la conexión falla

      _channel!.stream.listen(
        (data) {
          final decoded = jsonDecode(data as String) as Map<String, dynamic>;
          if (decoded['type'] == 'auth_success') {
            _reconnectAttempts = 0;
            _statusController.add(ConnectionStatus.connected);
          }
          _messageController.add(decoded);
        },
        onError: (_) => _handleDisconnect(),
        onDone: () => _handleDisconnect(),
      );

      _channel!.sink.add(jsonEncode({'type': 'auth', 'token': _lastToken}));
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    if (_manuallyDisconnected) return;

    _statusController.add(ConnectionStatus.disconnected);
    _reconnectAttempts++;

    // Backoff exponencial, con tope de 30 segundos entre intentos.
    final delaySeconds = (_reconnectAttempts * 2).clamp(2, 30);
    Timer(Duration(seconds: delaySeconds), () {
      if (!_manuallyDisconnected && _lastToken != null) {
        _openConnection();
      }
    });
  }

  void sendMessage({
    required String receiverId,
    required String type,
    required String ciphertextBase64,
    required String nonceBase64,
    String? audioBlobBase64,
    int? expirySeconds,
  }) {
    _channel?.sink.add(jsonEncode({
      'type': 'send_message',
      'payload': {
        'receiverId': receiverId,
        'type': type,
        'ciphertext': ciphertextBase64,
        'nonce': nonceBase64,
        if (audioBlobBase64 != null) 'audioBlob': audioBlobBase64,
        if (expirySeconds != null) 'expirySeconds': expirySeconds,
      },
    }));
  }

  void markRead(String messageId) {
    _channel?.sink.add(jsonEncode({'type': 'mark_read', 'messageId': messageId}));
  }

  void dispose() {
    _manuallyDisconnected = true;
    _channel?.sink.close();
    _messageController.close();
    _statusController.close();
  }
}