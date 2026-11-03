import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/models/chat_message.dart';

ChatMessage _msg(String id, {String? localId}) => ChatMessage(
      id: id,
      senderId: 'a',
      type: 'text',
      plaintext: 'hola',
      sentAt: DateTime.utc(2026, 1, 1),
      expiresAt: DateTime.utc(2026, 1, 2),
      isMine: true,
      localId: localId,
    );

void main() {
  test('un id provisional del cliente se detecta como pendiente', () {
    expect(_msg('c1700000000000-0').isPending, isTrue);
    expect(_msg('3f2b8c1e-5d4a-4c7b-9a10-0d6f2b7e1a11').isPending, isFalse);
  });

  test('localId se conserva cuando el servidor confirma el mensaje', () {
    final local = _msg('c1700000000000-0');
    final confirmed = local.copyWith(id: '3f2b8c1e-5d4a-4c7b-9a10-0d6f2b7e1a11');
    expect(confirmed.id, isNot(local.id));
    expect(confirmed.localId, local.localId);
  });

  test('formatRemaining elige la unidad adecuada', () {
    expect(formatRemaining(const Duration(seconds: 45)), '45 s');
    expect(formatRemaining(const Duration(minutes: 5)), '5 min');
    expect(formatRemaining(const Duration(hours: 23)), '23 h');
    expect(formatRemaining(const Duration(days: 7)), '7 d');
    expect(formatRemaining(const Duration(seconds: -3)), '0 s');
  });
}
