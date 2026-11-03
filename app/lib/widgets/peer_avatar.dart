import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Anillo alrededor del avatar, como las historias.
/// [idle] = anillo tenue; [active] = anillo de colores (hay un mensaje reciente suyo).
enum PeerRing { idle, active }

/// Avatar con la inicial del usuario y un color propio y estable: el mismo
/// nombre siempre sale del mismo color, así reconoces a cada persona de un vistazo.
class PeerAvatar extends StatelessWidget {
  final String username;
  final double size;
  final String? heroTag;
  final PeerRing? ring;

  const PeerAvatar({
    super.key,
    required this.username,
    this.size = 48,
    this.heroTag,
    this.ring,
  });

  static const _stroke = 2.5;
  static const _gap = 2.5;

  /// Tamaño total que ocupa con anillo (para que la lista no "salte").
  static double outerSize(double size) => size + 2 * (_stroke + _gap);

  // Paleta curada: todos armonizan con el morado de la app y llevan texto
  // blanco legible. El mismo nombre siempre cae en el mismo color.
  static const _palette = [
    Color(0xFF6A57C9),
    Color(0xFF8B4FB8),
    Color(0xFFB14E8C),
    Color(0xFF4E67C8),
    Color(0xFF3E8A8F),
    Color(0xFF5B7C4A),
  ];

  Color _colorFor(String name) {
    var hash = 0;
    for (final unit in name.toLowerCase().codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final initial = username.isEmpty ? '?' : username[0].toUpperCase();
    Widget avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _colorFor(username),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    if (heroTag != null) avatar = Hero(tag: heroTag!, child: avatar);

    if (ring != null) {
      final total = outerSize(size);
      final idleColor = Theme.of(context).colorScheme.onSurface
          .withValues(alpha: 0.15);
      avatar = SizedBox(
        width: total,
        height: total,
        child: CustomPaint(
          painter: _RingPainter(
            active: ring == PeerRing.active,
            idleColor: idleColor,
          ),
          child: Center(child: avatar),
        ),
      );
    }
    return ExcludeSemantics(child: avatar);
  }
}

class _RingPainter extends CustomPainter {
  final bool active;
  final Color idleColor;

  _RingPainter({required this.active, required this.idleColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = PeerAvatar._stroke;
    if (active) {
      paint.shader = AppGradients.ring.createShader(rect);
    } else {
      paint.color = idleColor;
    }
    canvas.drawCircle(
      rect.center,
      (size.width - PeerAvatar._stroke) / 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.active != active || old.idleColor != idleColor;
}
