import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/chat_websocket.dart';
import '../../core/api/settings_api.dart';
import '../../core/api/users_api.dart';
import '../../core/chat/chat_controller.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/chat_message.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/peer_avatar.dart';
import '../settings/settings_screen.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();

    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Familia'),
          actions: [
            IconButton(
              tooltip: 'Configuración',
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    settingsApi: context.read<SettingsApi>(),
                    storage: context.read<SecureStorageService>(),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _ConnectionBanner(status: chat.connectionStatus),
            Expanded(
              child: chat.familyUsers.isEmpty
                  ? const _EmptyFamily()
                  : RefreshIndicator(
                      onRefresh: chat.refresh,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: chat.familyUsers.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0)
                            return _Header(users: chat.familyUsers);
                          final FamilyUser peer = chat.familyUsers[index - 1];
                          final messages = chat.messagesWith(peer.id);
                          return _ConversationTile(
                            peer: peer,
                            last: messages.isEmpty ? null : messages.last,
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso de conexión: aparece y desaparece con una animación suave en vez de
/// empujar la lista de golpe. Solo se muestra cuando hay un problema.
class _ConnectionBanner extends StatelessWidget {
  final ConnectionStatus status;
  const _ConnectionBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final problem = status != ConnectionStatus.connected;
    final reconnecting =
        status == ConnectionStatus.reconnecting ||
        status == ConnectionStatus.connecting;
    final color = reconnecting ? AppColors.ember : AppColors.coral;

    return AnimatedSize(
      duration: AppMotion.base,
      curve: AppMotion.curve,
      child: problem
          ? Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                color: color.withValues(alpha: 0.16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (reconnecting)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    else
                      Icon(Icons.cloud_off_rounded, size: 16, color: color),
                    const SizedBox(width: 10),
                    Text(
                      reconnecting
                          ? 'Reconectando...'
                          : 'Sin conexión al servidor',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final FamilyUser peer;
  final ChatMessage? last;

  const _ConversationTile({required this.peer, required this.last});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);

    Widget preview;
    if (last == null) {
      preview = Text('Toca para escribir', style: muted, maxLines: 1);
    } else {
      final prefix = last!.isMine ? 'Tú: ' : '';
      preview = Row(
        children: [
          if (last!.type == 'audio') ...[
            Icon(Icons.mic_rounded, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              last!.type == 'audio'
                  ? '${prefix}Nota de voz'
                  : '$prefix${last!.plaintext}',
              style: muted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => ChatScreen(peer: peer))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 80),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              PeerAvatar(
                username: peer.username,
                size: 46,
                heroTag: 'avatar-${peer.id}',
                ring: (last != null && !last!.isMine)
                    ? PeerRing.active
                    : PeerRing.idle,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            peer.username,
                            style: text.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (last != null)
                          Text(
                            TimeOfDay.fromDateTime(last!.sentAt.toLocal())
                                .format(context),
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    preview,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFamily extends StatelessWidget {
  const _EmptyFamily();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_add_outlined, size: 44, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'Aún no hay nadie más',
              style: text.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Pide a un familiar que cree su cuenta en su teléfono. '
              'Aparecerá aquí en cuanto se registre.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Título grande y fila de contactos (como las historias): acceso rápido
/// y mucho más color que una lista plana.
class _Header extends StatelessWidget {
  final List<FamilyUser> users;
  const _Header({required this.users});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Text(
            'Mensajes',
            style: text.headlineMedium?.copyWith(fontSize: 30),
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final peer = users[i];
              final hasNew = (() {
                final m = context.read<ChatController>().messagesWith(peer.id);
                return m.isNotEmpty && !m.last.isMine;
              })();
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChatScreen(peer: peer)),
                ),
                child: SizedBox(
                  width: 70,
                  child: Column(
                    children: [
                      PeerAvatar(
                        username: peer.username,
                        size: 58,
                        ring: hasNew ? PeerRing.active : PeerRing.idle,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        peer.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
