import 'package:flutter/material.dart';
import '../../core/api/settings_api.dart';
import '../../core/storage/secure_storage_service.dart';

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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await widget.storage.getToken();
    if (token == null) return;

    try {
      final current = await widget.settingsApi.getDefaultExpiry(token);
      setState(() {
        _selectedSeconds = current;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save(int seconds) async {
    final token = await widget.storage.getToken();
    if (token == null) return;

    setState(() => _saving = true);
    try {
      await widget.settingsApi.updateDefaultExpiry(token, seconds);
      setState(() {
        _selectedSeconds = seconds;
        _saving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferencia guardada')),
        );
      }
    } catch (_) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Tus mensajes se autodestruyen automáticamente después de:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...expiryOptions.map(
                  (option) => RadioListTile<int>(
                    title: Text(option.label),
                    value: option.seconds,
                    groupValue: _selectedSeconds,
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null) _save(value);
                          },
                  ),
                ),
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }
}