import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionStatus { connecting, connected, disconnected, reconnecting }

class ChatWebSocket {
  final String wsUrl;
  WebSocketChannel? _channel;
  String? _lastToken;
  bool _manuallyDisconnected = false;
  bool _connected = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();

  ChatWebSocket({required this.wsUrl});

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<ConnectionStatus> get status => _statusController.stream;

  /// true solo cuando el servidor ya confirmó la autenticación (auth_success).
  bool get isConnected => _connected;

  Future<void> connect(String token) async {
    _lastToken = token;
    _manuallyDisconnected = false;
    await _openConnection();
  }

  Future<void> _openConnection() async {
    _statusController.add(
      _reconnectAttempts == 0
          ? ConnectionStatus.connecting
          : ConnectionStatus.reconnecting,
    );

    // Cerramos la conexión anterior (si quedó alguna) antes de abrir otra.
    final old = _channel;
    _channel = null;
    old?.sink.close();

    try {
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel = channel;
      await channel.ready; // lanza si la conexión falla

      channel.stream.listen(
        (data) {
          final decoded = jsonDecode(data as String) as Map<String, dynamic>;
          if (decoded['type'] == 'auth_success') {
            _reconnectAttempts = 0;
            _connected = true;
            _statusController.add(ConnectionStatus.connected);
          }
          _messageController.add(decoded);
        },
        onError: (_) => _onChannelClosed(channel),
        onDone: () => _onChannelClosed(channel),
      );

      channel.sink.add(jsonEncode({'type': 'auth', 'token': _lastToken}));
    } catch (_) {
      _handleDisconnect();
    }
  }

  /// Ignora el cierre de canales viejos: solo reaccionamos al canal actual.
  void _onChannelClosed(WebSocketChannel closed) {
    if (!identical(closed, _channel)) return;
    _handleDisconnect();
  }

  void _handleDisconnect() {
    if (_manuallyDisconnected) return;
    _connected = false;

    // onError y onDone suelen dispararse juntos: con un solo reintento pendiente basta.
    if (_reconnectTimer?.isActive ?? false) return;

    _statusController.add(ConnectionStatus.disconnected);
    _reconnectAttempts++;

    // Retroceso lineal, con tope de 30 segundos entre intentos.
    final delaySeconds = (_reconnectAttempts * 2).clamp(2, 30);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectTimer = null;
      if (!_manuallyDisconnected && _lastToken != null) {
        _openConnection();
      }
    });
  }

  /// Devuelve false si no hay conexión: el mensaje NO se envió y el llamador
  /// debe avisar al usuario en vez de mostrarlo como enviado.
  bool sendMessage({
    required String receiverId,
    required String type,
    required String ciphertextBase64,
    required String nonceBase64,
    String? clientId,
    int? expirySeconds,
  }) {
    final channel = _channel;
    if (!_connected || channel == null) return false;

    try {
      channel.sink.add(
        jsonEncode({
          'type': 'send_message',
          'payload': {
            'receiverId': receiverId,
            'type': type,
            'ciphertext': ciphertextBase64,
            'nonce': nonceBase64,
            'clientId': ?clientId,
            'expirySeconds': ?expirySeconds,
          },
        }),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void markRead(String messageId) {
    if (!_connected) return;
    _channel?.sink.add(
      jsonEncode({'type': 'mark_read', 'messageId': messageId}),
    );
  }

  void dispose() {
    _manuallyDisconnected = true;
    _connected = false;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _messageController.close();
    _statusController.close();
  }
}
