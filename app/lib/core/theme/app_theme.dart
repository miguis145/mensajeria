import 'package:flutter/material.dart';

/// Colores fijos de la marca. El resto sale del ColorScheme (claro/oscuro).
class AppColors {
  /// Morado suave: el color principal (mis burbujas, botones, selección).
  static const violet = Color(0xFF6A57C9);

  /// Fondo del modo claro: lavanda casi blanca (no blanco puro, cansa menos).
  static const mist = Color(0xFFF5F3FA);

  /// Ámbar: "este mensaje está por desaparecer".
  static const ember = Color(0xFFE8A33D);

  /// Coral: grabando / error / sin conexión.
  static const coral = Color(0xFFD64F42);
}

/// Degradados de la marca: dan el aire "social" (burbujas, anillos, fondo).
class AppGradients {
  /// Mis burbujas, botones principales y logo: violeta que vira a magenta.
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6A57F0), Color(0xFFA63FCB)],
  );

  /// Anillo de un contacto con mensaje reciente (como las historias).
  static const ring = SweepGradient(
    colors: [
      Color(0xFF8B5CF6),
      Color(0xFFD946A8),
      Color(0xFFFF7A59),
      Color(0xFFFFB84D),
      Color(0xFF8B5CF6),
    ],
  );

  /// Fondo de las pantallas: lavanda a rosa suave de día; violeta profundo de noche.
  static LinearGradient backdrop(Brightness b) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: b == Brightness.dark
        ? const [Color(0xFF1E1338), Color(0xFF0F0C1B)]
        : const [Color(0xFFEBE3FF), Color(0xFFFBE8F4)],
  );
}

/// Duraciones y curvas de movimiento. Todas < 300 ms para que nada bloquee.
class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 220);
  static const curve = Curves.easeOutCubic;
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final seeded = ColorScheme.fromSeed(
      seedColor: AppColors.violet,
      brightness: brightness,
    );

    // Se fijan a mano los colores que forman la identidad (contraste verificado:
    // texto sobre "principal" ≥ 5:1 en ambos modos).
    final scheme = isLight
        ? seeded.copyWith(
            primary: AppColors.violet,
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFFE7E2F8),
            onPrimaryContainer: const Color(0xFF2A2060),
            surface: AppColors.mist,
            onSurface: const Color(0xFF1F1B2E),
            onSurfaceVariant: const Color(0xFF6B6580),
            surfaceContainerHigh: Colors.white,
            surfaceContainerHighest: const Color(0xFFECE8F7),
            error: AppColors.coral,
          )
        : seeded.copyWith(
            primary: const Color(0xFFA99BF0),
            onPrimary: const Color(0xFF1A1530),
            primaryContainer: const Color(0xFF352F55),
            onPrimaryContainer: const Color(0xFFE7E2F8),
            surface: const Color(0xFF14121D),
            onSurface: const Color(0xFFECE9F7),
            onSurfaceVariant: const Color(0xFFB5AFCB),
            surfaceContainerHigh: const Color(0xFF201D2E),
            surfaceContainerHighest: const Color(0xFF2A2640),
            error: AppColors.coral,
          );

    final base = ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      useMaterial3: true,
    );
    final text = base.textTheme;

    return base.copyWith(
      scaffoldBackgroundColor: isLight ? AppColors.mist : scheme.surface,
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: text.bodyLarge?.copyWith(height: 1.35),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.3),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// "3 h", "2 d", "45 s"... para mostrar cuánto le queda a un mensaje.
String formatRemaining(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds < 0 ? 0 : d.inSeconds} s';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 48) return '${d.inHours} h';
  return '${d.inDays} d';
}
