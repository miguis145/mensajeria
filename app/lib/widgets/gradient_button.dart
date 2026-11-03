import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Botón principal con degradado de la marca (login, registro).
class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    const radius = BorderRadius.all(Radius.circular(16));

    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        opacity: enabled ? 1 : 0.55,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: const BoxDecoration(
              gradient: AppGradients.brand,
              borderRadius: radius,
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: onPressed,
              child: SizedBox(
                height: 54,
                width: double.infinity,
                child: Center(
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
