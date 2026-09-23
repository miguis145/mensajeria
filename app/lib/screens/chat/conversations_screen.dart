import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/chat/chat_controller.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Familia')),
      body: chat.familyUsers.isEmpty
          ? const Center(child: Text('Nadie más se ha registrado todavía'))
          : ListView.builder(
              itemCount: chat.familyUsers.length,
              itemBuilder: (context, index) {
                final peer = chat.familyUsers[index];
                return ListTile(
                  leading: CircleAvatar(child: Text(peer.username[0].toUpperCase())),
                  title: Text(peer.username),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ChatScreen(peer: peer)),
                  ),
                );
              },
            ),
    );
  }
}


body: Column(
  children: [
    if (chat.connectionStatus != ConnectionStatus.connected)
      Container(
        width: double.infinity,
        color: Colors.orange.shade100,
        padding: const EdgeInsets.all(8),
        child: Text(
          chat.connectionStatus == ConnectionStatus.reconnecting
              ? 'Reconectando...'
              : 'Sin conexión al servidor',
          textAlign: TextAlign.center,
        ),
      ),
    Expanded(
      child: chat.familyUsers.isEmpty
          ? const Center(child: Text('Nadie más se ha registrado todavía'))
          : ListView.builder(/* ... el resto igual que antes ... */),
    ),
  ],
),