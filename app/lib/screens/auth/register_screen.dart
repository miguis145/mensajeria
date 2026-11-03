import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_state.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/gradient_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _hidePassword = true;

  // Las mismas reglas que valida el servidor: así el error sale aquí, al instante.
  static final _usernameRule = RegExp(r'^[a-zA-Z0-9_]{3,32}$');

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final authState = context.read<AuthState>();
    final success = await authState.register(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              authState.errorMessage ?? 'No se pudo crear la cuenta',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.select<AuthState, bool>((s) => s.isLoading);
    final scheme = Theme.of(context).colorScheme;

    return AuthLayout(
      showBack: true,
      title: 'Crea tu cuenta',
      subtitle: 'Solo toma un momento.',
      children: [
        Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: AutofillGroup(
            child: Column(
              children: [
                TextFormField(
                  controller: _usernameController,
                  enabled: !loading,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    helperText:
                        '3 a 32 caracteres: letras, números y guion bajo',
                  ),
                  autofillHints: const [AutofillHints.newUsername],
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  validator: (v) =>
                      (v == null || !_usernameRule.hasMatch(v.trim()))
                      ? 'Usa 3 a 32 letras, números o _'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  enabled: !loading,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    helperText: 'Mínimo 8 caracteres',
                    suffixIcon: IconButton(
                      tooltip: _hidePassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                    ),
                  ),
                  obscureText: _hidePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) => (v == null || v.length < 8)
                      ? 'Mínimo 8 caracteres'
                      : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.key_rounded,
                size: 20,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tu llave de cifrado se guarda solo en este teléfono. Si lo cambias '
                  'o reinstalas la app, no podrás recuperar tus mensajes.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onPrimaryContainer),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GradientButton(
          onPressed: loading ? null : _submit,
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text('Crear cuenta'),
        ),
      ],
    );
  }
}
