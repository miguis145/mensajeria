import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Fondo con degradado para una pantalla. Se usa envolviendo un Scaffold que
/// tenga `backgroundColor: Colors.transparent`.
class AppBackdrop extends StatelessWidget {
  final Widget child;
  const AppBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.backdrop(Theme.of(context).brightness),
      ),
      child: child,
    );
  }
}
