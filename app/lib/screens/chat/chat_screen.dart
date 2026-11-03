import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/api/chat_websocket.dart';
import '../../core/api/users_api.dart';
import '../../core/audio/audio_player_service.dart';
import '../../core/audio/audio_recorder_service.dart';
import '../../core/chat/chat_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/chat_message.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/peer_avatar.dart';

/// Menos de esto de grabación se considera un toque accidental y no se envía.
const _minRecording = Duration(seconds: 1);

/// Cuánto hay que deslizar a la izquierda para cancelar una nota de voz.
const _cancelDragDistance = 90.0;

/// En los últimos segundos de vida el mensaje se va apagando.
const _fadeWindow = Duration(seconds: 10);

class ChatScreen extends StatefulWidget {
  final FamilyUser peer;
  const ChatScreen({super.key, required this.peer});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _recorder = AudioRecorderService();
  final _player = AudioPlayerService();

  // Estos "notifiers" actualizan solo la parte de la pantalla que cambia
  // (un reloj, un cronómetro...) sin reconstruir toda la lista cada segundo.
  final _now = ValueNotifier<DateTime>(DateTime.now());
  final _playProgress = ValueNotifier<double>(0);
  final _recElapsed = ValueNotifier<Duration>(Duration.zero);

  Timer? _clock;
  Timer? _recTimer;
  StreamSubscription<void>? _completedSub;
  StreamSubscription<double>? _progressSub;

  bool _hasText = false;
  bool _showJump = false;
  bool _isRecording = false;
  bool _willCancel = false;
  DateTime? _recStartedAt;
  Future<bool>? _startFuture;
  String? _playingMessageId;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final has = _textController.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _scrollController.addListener(() {
      final far =
          _scrollController.hasClients && _scrollController.offset > 300;
      if (far != _showJump) setState(() => _showJump = far);
    });
    _clock = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _now.value = DateTime.now(),
    );
    _completedSub = _player.onCompleted.listen((_) {
      _playProgress.value = 0;
      if (mounted) setState(() => _playingMessageId = null);
    });
    _progressSub = _player.progress.listen((p) => _playProgress.value = p);
  }

  @override
  void dispose() {
    _clock?.cancel();
    _recTimer?.cancel();
    _completedSub?.cancel();
    _progressSub?.cancel();
    _now.dispose();
    _playProgress.dispose();
    _recElapsed.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ avisos

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _showNotSent() => _snack('Sin conexión: el mensaje no se envió');

  void _jumpToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: AppMotion.base,
      curve: AppMotion.curve,
    );
  }

  // ------------------------------------------------------------------- texto

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final sent = context.read<ChatController>().sendText(widget.peer, text);
    if (sent) {
      HapticFeedback.lightImpact();
      _textController.clear();
      _jumpToBottom();
    } else {
      _showNotSent(); // conservamos el texto para que pueda reintentar
    }
  }

  // ------------------------------------------------------------------- audio

  Future<bool> _beginRecording() async {
    if (!await _recorder.hasPermission()) {
      _snack('Necesitas dar permiso de micrófono');
      return false;
    }
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.startRecording(path);
    } catch (_) {
      _snack('No se pudo iniciar la grabación');
      return false;
    }
    _recStartedAt = DateTime.now();
    _recElapsed.value = Duration.zero;
    _recTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _recElapsed.value = DateTime.now().difference(_recStartedAt!);
    });
    if (mounted)
      setState(() {
        _isRecording = true;
        _willCancel = false;
      });
    return true;
  }

  void _onMicPressStart() {
    HapticFeedback.mediumImpact(); // vibración al empezar a grabar
    _stopPlayback(); // para que el micrófono no grabe el audio que suena
    _startFuture = _beginRecording();
  }

  void _onMicDrag(LongPressMoveUpdateDetails details) {
    if (!_isRecording) return;
    final cancel = details.offsetFromOrigin.dx < -_cancelDragDistance;
    if (cancel != _willCancel) {
      HapticFeedback.selectionClick();
      setState(() => _willCancel = cancel);
    }
  }

  /// Termina la grabación. Espera a que haya terminado de arrancar: así, si el
  /// usuario suelta muy rápido, la grabación no se queda abierta en segundo plano.
  Future<void> _finishRecording({required bool cancel}) async {
    final started = await (_startFuture ?? Future<bool>.value(false));
    _startFuture = null;
    if (!started) return;

    _recTimer?.cancel();
    final elapsed = DateTime.now().difference(_recStartedAt!);
    if (mounted) {
      setState(() {
        _isRecording = false;
        _willCancel = false;
      });
    }

    final audioBytes = await _recorder.stopRecording();
    if (cancel || audioBytes == null || audioBytes.isEmpty) return;
    if (elapsed < _minRecording) {
      _snack('Mantén presionado el micrófono para grabar');
      return;
    }
    if (!mounted) return;

    final sent = context.read<ChatController>().sendAudio(
      widget.peer,
      audioBytes,
    );
    if (sent) {
      HapticFeedback.lightImpact();
      _jumpToBottom();
    } else {
      _showNotSent();
    }
  }

  Future<void> _stopPlayback() async {
    if (_playingMessageId == null) return;
    await _player.stop();
    _playProgress.value = 0;
    if (mounted) setState(() => _playingMessageId = null);
  }

  Future<void> _togglePlay(ChatMessage msg) async {
    if (msg.audioBytes == null) return;

    if (_playingMessageId == msg.localId) {
      await _stopPlayback();
      return;
    }
    _playProgress.value = 0;
    setState(() => _playingMessageId = msg.localId);
    try {
      await _player.playBytes(msg.audioBytes!, msg.localId);
    } catch (_) {
      if (mounted) setState(() => _playingMessageId = null);
      _snack('No se pudo reproducir la nota de voz');
    }
  }

  // ------------------------------------------------------------------ pantalla

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    final messages = chat.messagesWith(widget.peer.id);

    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(chat.connectionStatus),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (messages.isEmpty)
                    const _EmptyChat()
                  else
                    ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) =>
                          _buildRow(messages, messages.length - 1 - index),
                    ),
                  Positioned(
                    right: 16,
                    bottom: 12,
                    child: AnimatedScale(
                      scale: _showJump ? 1 : 0,
                      duration: AppMotion.fast,
                      curve: AppMotion.curve,
                      child: FloatingActionButton.small(
                        heroTag: null,
                        tooltip: 'Ir al último mensaje',
                        onPressed: _jumpToBottom,
                        child: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildComposer(chat.connectionStatus),
          ],
        ),
      ),
    );
  }

  static final _pillBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(28),
    borderSide: BorderSide.none,
  );

  PreferredSizeWidget _buildAppBar(ConnectionStatus status) {
    final scheme = Theme.of(context).colorScheme;
    final online = status == ConnectionStatus.connected;
    final subtitle = switch (status) {
      ConnectionStatus.connected => 'Cifrado de extremo a extremo',
      ConnectionStatus.reconnecting ||
      ConnectionStatus.connecting => 'Reconectando...',
      ConnectionStatus.disconnected => 'Sin conexión',
    };

    return AppBar(
      titleSpacing: 0,
      title: Row(
        children: [
          PeerAvatar(
            username: widget.peer.username,
            size: 38,
            heroTag: 'avatar-${widget.peer.id}',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.peer.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                AnimatedSwitcher(
                  duration: AppMotion.fast,
                  child: Text(
                    subtitle,
                    key: ValueKey(subtitle),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: online ? scheme.onSurfaceVariant : AppColors.coral,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(List<ChatMessage> messages, int i) {
    final msg = messages[i];
    final older = i > 0 ? messages[i - 1] : null;
    final newer = i < messages.length - 1 ? messages[i + 1] : null;

    bool sameGroup(ChatMessage a, ChatMessage b) =>
        a.isMine == b.isMine &&
        b.sentAt.difference(a.sentAt).abs() < const Duration(minutes: 2);

    final joinsOlder = older != null && sameGroup(older, msg);
    final joinsNewer = newer != null && sameGroup(msg, newer);

    return _MessageRow(
      key: ValueKey(msg.localId),
      message: msg,
      joinsOlder: joinsOlder,
      joinsNewer: joinsNewer,
      now: _now,
      playProgress: _playProgress,
      isPlaying: _playingMessageId == msg.localId,
      onTogglePlay: () => _togglePlay(msg),
    );
  }

  Widget _buildComposer(ConnectionStatus status) {
    final scheme = Theme.of(context).colorScheme;
    final offline = status != ConnectionStatus.connected;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.fast,
                child: _isRecording
                    ? _RecordingBar(
                        key: const ValueKey('rec'),
                        elapsed: _recElapsed,
                        willCancel: _willCancel,
                      )
                    : TextField(
                        key: const ValueKey('text'),
                        controller: _textController,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 4000,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: offline
                              ? 'Sin conexión'
                              : 'Escribe un mensaje',
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          border: _pillBorder,
                          enabledBorder: _pillBorder,
                          focusedBorder: _pillBorder,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: AppMotion.fast,
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: _hasText
                  ? _GradientCircle(
                      key: const ValueKey('send'),
                      size: 52,
                      tooltip: 'Enviar mensaje',
                      onTap: _sendText,
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                      ),
                    )
                  : _MicButton(
                      key: const ValueKey('mic'),
                      recording: _isRecording,
                      willCancel: _willCancel,
                      color: scheme.primary,
                      onTapHint: () => _snack(
                        'Mantén presionado para grabar una nota de voz',
                      ),
                      onStart: _onMicPressStart,
                      onMove: _onMicDrag,
                      onEnd: () => _finishRecording(cancel: _willCancel),
                      onCancel: () => _finishRecording(cancel: true),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================ piezas de la UI

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

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
            Icon(Icons.lock_outline_rounded, size: 40, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'Aquí solo están ustedes dos',
              style: text.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Los mensajes se cifran en tu teléfono y se borran solos '
              'cuando se cumple el tiempo que elegiste en Configuración.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón de micrófono: mantener presionado = grabar; soltar = enviar;
/// deslizar a la izquierda y soltar = cancelar. Un toque corto explica cómo se usa.
class _MicButton extends StatelessWidget {
  final bool recording;
  final bool willCancel;
  final Color color;
  final VoidCallback onTapHint;
  final VoidCallback onStart;
  final void Function(LongPressMoveUpdateDetails) onMove;
  final VoidCallback onEnd;
  final VoidCallback onCancel;

  const _MicButton({
    super.key,
    required this.recording,
    required this.willCancel,
    required this.color,
    required this.onTapHint,
    required this.onStart,
    required this.onMove,
    required this.onEnd,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final size = recording ? 64.0 : 52.0;
    return Semantics(
      button: true,
      label: 'Mantén presionado para grabar una nota de voz',
      child: GestureDetector(
        onTap: onTapHint,
        onLongPressStart: (_) => onStart(),
        onLongPressMoveUpdate: onMove,
        onLongPressEnd: (_) => onEnd(),
        onLongPressCancel: onCancel,
        child: SizedBox(
          width: 64, // el área táctil no cambia de tamaño al crecer el botón
          height: 64,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: recording ? null : AppGradients.brand,
                color: recording
                    ? (willCancel ? Colors.grey : AppColors.coral)
                    : null,
              ),
              child: Icon(
                willCancel ? Icons.delete_outline_rounded : Icons.mic_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra que reemplaza al campo de texto mientras se graba.
class _RecordingBar extends StatefulWidget {
  final ValueNotifier<Duration> elapsed;
  final bool willCancel;

  const _RecordingBar({
    super.key,
    required this.elapsed,
    required this.willCancel,
  });

  @override
  State<_RecordingBar> createState() => _RecordingBarState();
}

class _RecordingBarState extends State<_RecordingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String _format(Duration d) {
    final m = d.inMinutes.toString().padLeft(1, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final cancel = widget.willCancel;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cancel
            ? scheme.surfaceContainerHighest
            : AppColors.coral.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          FadeTransition(
            opacity: reduceMotion
                ? const AlwaysStoppedAnimation(1.0)
                : Tween(begin: 0.3, end: 1.0).animate(_pulse),
            child: Icon(
              cancel ? Icons.delete_outline_rounded : Icons.fiber_manual_record,
              size: 16,
              color: cancel ? scheme.onSurfaceVariant : AppColors.coral,
            ),
          ),
          const SizedBox(width: 10),
          ValueListenableBuilder<Duration>(
            valueListenable: widget.elapsed,
            builder: (_, d, _) => Text(
              _format(d),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              cancel ? 'Suelta para cancelar' : '‹ Desliza para cancelar',
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una fila de mensaje: se anima al aparecer (solo si es nuevo) y se va
/// apagando en sus últimos segundos de vida.
class _MessageRow extends StatelessWidget {
  final ChatMessage message;
  final bool joinsOlder;
  final bool joinsNewer;
  final ValueNotifier<DateTime> now;
  final ValueNotifier<double> playProgress;
  final bool isPlaying;
  final VoidCallback onTogglePlay;

  const _MessageRow({
    super.key,
    required this.message,
    required this.joinsOlder,
    required this.joinsNewer,
    required this.now,
    required this.playProgress,
    required this.isPlaying,
    required this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context) {
    final msg = message;
    final scheme = Theme.of(context).colorScheme;
    final mine = msg.isMine;

    const big = Radius.circular(20);
    const small = Radius.circular(6);
    // La esquina del lado del emisor se "cierra" cuando el mensaje continúa un grupo.
    final radius = BorderRadius.only(
      topLeft: !mine && joinsOlder ? small : big,
      bottomLeft: !mine && joinsNewer ? small : big,
      topRight: mine && joinsOlder ? small : big,
      bottomRight: mine && joinsNewer ? small : big,
    );

    final fg = mine ? Colors.white : scheme.onSurface;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;

    Widget bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        decoration: BoxDecoration(
          gradient: mine ? AppGradients.brand : null,
          color: mine ? null : scheme.surfaceContainerHigh,
          borderRadius: radius,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: msg.type == 'audio'
                  ? _AudioContent(
                      seed: msg.localId,
                      isPlaying: isPlaying,
                      progress: playProgress,
                      color: fg,
                      onTap: onTogglePlay,
                    )
                  : Text(
                      msg.plaintext,
                      style: TextStyle(color: fg, fontSize: 16, height: 1.3),
                    ),
            ),
            _Footer(message: msg, color: fg, now: now),
          ],
        ),
      ),
    );

    // Se apaga en los últimos segundos (excepto los que aún no confirma el servidor).
    bubble = ValueListenableBuilder<DateTime>(
      valueListenable: now,
      child: bubble,
      builder: (_, time, child) {
        final remaining = msg.expiresAt.difference(time);
        var opacity = 1.0;
        if (!msg.isPending && remaining < _fadeWindow) {
          opacity =
              0.35 +
              0.65 *
                  (remaining.inMilliseconds / _fadeWindow.inMilliseconds).clamp(
                    0.0,
                    1.0,
                  );
        }
        return Opacity(opacity: opacity, child: child);
      },
    );

    final recent =
        DateTime.now().difference(msg.sentAt).abs() <
        const Duration(seconds: 3);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (recent && !reduceMotion) {
      bubble = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.base,
        curve: AppMotion.curve,
        child: bubble,
        builder: (_, t, child) => Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.92 + 0.08 * t,
            alignment: mine ? Alignment.bottomRight : Alignment.bottomLeft,
            child: child,
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: joinsOlder ? 2 : 10),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: bubble,
      ),
    );
  }
}

/// Hora de envío, estado y tiempo que le queda al mensaje + barra de vida.
class _Footer extends StatelessWidget {
  final ChatMessage message;
  final Color color;
  final ValueNotifier<DateTime> now;

  const _Footer({
    required this.message,
    required this.color,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(message.sentAt.toLocal())
        .format(context);
    final small = TextStyle(color: color.withValues(alpha: 0.75), fontSize: 11);

    return ValueListenableBuilder<DateTime>(
      valueListenable: now,
      builder: (_, current, _) {
        final remaining = message.expiresAt.difference(current);
        final total = message.expiresAt.difference(message.sentAt);
        final urgent =
            !message.isPending && remaining < const Duration(minutes: 1);
        final fraction = total.inMilliseconds <= 0
            ? 0.0
            : (remaining.inMilliseconds / total.inMilliseconds)
                  .clamp(0.0, 1.0)
                  .toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 12, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(time, style: small),
                  const SizedBox(width: 10),
                  if (message.isPending) ...[
                    Icon(Icons.schedule_rounded, size: 12, color: small.color),
                    const SizedBox(width: 3),
                    Text('Enviando', style: small),
                  ] else ...[
                    Icon(
                      Icons.hourglass_bottom_rounded,
                      size: 12,
                      color: urgent ? AppColors.ember : small.color,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      formatRemaining(remaining),
                      style: small.copyWith(
                        color: urgent ? AppColors.ember : small.color,
                        fontWeight: urgent ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!message.isPending)
              LinearProgressIndicator(
                value: fraction,
                minHeight: 3,
                backgroundColor: color.withValues(alpha: 0.12),
                color: urgent ? AppColors.ember : color.withValues(alpha: 0.5),
              ),
          ],
        );
      },
    );
  }
}

/// Nota de voz: botón play/pausa + onda que se va llenando mientras suena.
class _AudioContent extends StatefulWidget {
  final String seed;
  final bool isPlaying;
  final ValueNotifier<double> progress;
  final Color color;
  final VoidCallback onTap;

  const _AudioContent({
    required this.seed,
    required this.isPlaying,
    required this.progress,
    required this.color,
    required this.onTap,
  });

  @override
  State<_AudioContent> createState() => _AudioContentState();
}

class _AudioContentState extends State<_AudioContent> {
  // La onda es decorativa pero estable: sale del id del mensaje, así cada nota
  // siempre se ve igual.
  late final List<double> _bars = () {
    final rnd = math.Random(widget.seed.hashCode);
    return List<double>.generate(28, (_) => 0.25 + 0.75 * rnd.nextDouble());
  }();

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            tooltip: widget.isPlaying
                ? 'Pausar nota de voz'
                : 'Reproducir nota de voz',
            onPressed: widget.onTap,
            style: IconButton.styleFrom(
              backgroundColor: color.withValues(alpha: 0.18),
              foregroundColor: color,
            ),
            icon: Icon(
              widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 10),
        ValueListenableBuilder<double>(
          valueListenable: widget.progress,
          builder: (_, p, _) => CustomPaint(
            size: const Size(112, 28),
            painter: _WavePainter(
              bars: _bars,
              progress: widget.isPlaying ? p : 0,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  final List<double> bars;
  final double progress;
  final Color color;

  _WavePainter({
    required this.bars,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / bars.length;
    final paint = Paint()
      ..strokeWidth = slot * 0.55
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < bars.length; i++) {
      final played = (i + 1) / bars.length <= progress;
      paint.color = played ? color : color.withValues(alpha: 0.4);
      final h = size.height * bars[i];
      final x = slot * i + slot / 2;
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.progress != progress || old.color != color;
}

/// Botón circular con degradado de la marca (enviar).
class _GradientCircle extends StatelessWidget {
  final double size;
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  const _GradientCircle({
    super.key,
    required this.size,
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.brand,
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
