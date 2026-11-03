import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/chat_message.dart';

void main() {
  group('ChatMessage.copyWith', () {
    ChatMessage local() => ChatMessage(
          id: 'c1-0',
          senderId: 'yo',
          type: 'text',
          plaintext: 'hola',
          sentAt: DateTime.utc(2026, 11, 3, 10),
          expiresAt: DateTime.utc(2026, 11, 3, 10, 1),
          isMine: true,
        );

    test('al confirmar el envío cambia id y caducidad, y nada más', () {
      final confirmed = local().copyWith(
        id: 'srv-1',
        expiresAt: DateTime.utc(2026, 11, 4, 10),
      );

      expect(confirmed.id, 'srv-1');
      expect(confirmed.expiresAt, DateTime.utc(2026, 11, 4, 10));
      expect(confirmed.plaintext, 'hola');
      expect(confirmed.sentAt, DateTime.utc(2026, 11, 3, 10));
      expect(confirmed.isMine, isTrue);
    });

    test('sin argumentos conserva todo', () {
      final copy = local().copyWith();
      expect(copy.id, 'c1-0');
      expect(copy.expiresAt, DateTime.utc(2026, 11, 3, 10, 1));
    });

    test('no modifica el mensaje original', () {
      final original = local();
      original.copyWith(id: 'otro');
      expect(original.id, 'c1-0');
    });
  });
}
