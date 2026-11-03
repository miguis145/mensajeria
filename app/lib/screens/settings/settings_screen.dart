import 'package:flutter/material.dart';

import '../../core/api/settings_api.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_backdrop.dart';

class ExpiryOption {
  final String label;
  final int seconds;
  const ExpiryOption(this.label, this.seconds);
}

const List<ExpiryOption> expiryOptions = [
  ExpiryOption('1 hora', 3600),
  ExpiryOption('1 día', 86400),
  ExpiryOption('1 semana', 604800),
  ExpiryOption('30 días', 2592000),
];

class SettingsScreen extends StatefulWidget {
  final SettingsApi settingsApi;
  final SecureStorageService storage;

  const SettingsScreen({
    super.key,
    required this.settingsApi,
    required this.storage,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int? _selectedSeconds;
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    final token = await widget.storage.getToken();
    if (token == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final current = await widget.settingsApi.getDefaultExpiry(token);
      if (!mounted) return;
      setState(() {
        _selectedSeconds = current;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  /// Actualización "optimista": la opción se marca al instante y, si el
  /// servidor falla, se devuelve a la anterior. Así el toque se siente inmediato.
  Future<void> _save(int seconds) async {
    if (seconds == _selectedSeconds) return;
    final token = await widget.storage.getToken();
    if (token == null) return;

    final previous = _selectedSeconds;
    setState(() => _selectedSeconds = seconds);
    try {
      await widget.settingsApi.updateDefaultExpiry(token, seconds);
    } catch (_) {
      if (!mounted) return;
      setState(() => _selectedSeconds = previous);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar. Inténtalo de nuevo.'),
          ),
        );
    }
  }

  String _labelFor(int seconds) => formatRemaining(Duration(seconds: seconds));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final options = [...expiryOptions];
    final current = _selectedSeconds;
    if (current != null && !options.any((o) => o.seconds == current)) {
      options.add(
        ExpiryOption('Personalizado (${_labelFor(current)})', current),
      );
    }

    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Configuración')),
        body: AnimatedSwitcher(
          duration: AppMotion.base,
          child: _loading
              ? const Center(
                  key: ValueKey('loading'),
                  child: CircularProgressIndicator(),
                )
              : _loadFailed
              ? Center(
                  key: const ValueKey('failed'),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 40,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No se pudo cargar tu preferencia',
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(160, 48),
                          ),
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  key: const ValueKey('content'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Text(
                      'Los mensajes se borran solos',
                      style: text.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Elige cuánto tiempo se guardan en tu teléfono. Cada persona '
                      'decide el suyo, y solo cambia para los mensajes nuevos.',
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final option in options)
                      _ExpiryTile(
                        label: option.label,
                        selected: option.seconds == _selectedSeconds,
                        onTap: () => _save(option.seconds),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Opción seleccionable (reemplaza a RadioListTile, que está en desuso).
class _ExpiryTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ExpiryTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        label: label,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          decoration: BoxDecoration(
            gradient: selected ? AppGradients.brand : null,
            color: selected ? null : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: selected
                                    ? Colors.white
                                    : scheme.onSurface,
                              ),
                        ),
                      ),
                      AnimatedOpacity(
                        duration: AppMotion.fast,
                        opacity: selected ? 1 : 0,
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
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
