import 'package:flutter/material.dart';

import '../main.dart';
import '../state/auth_controller.dart';
import 'auth_widgets.dart';

/// Tela de cadastro. Valida nome/e-mail/senha localmente (espelhando o
/// backend) e, em sucesso, faz auto-login via [AuthController.register].
class RegisterScreen extends StatefulWidget {
  final AuthController auth;

  const RegisterScreen({super.key, required this.auth});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    widget.auth.clearError();
    if (!_formKey.currentState!.validate()) return;
    final ok = await widget.auth.register(
      _name.text.trim(),
      _email.text.trim(),
      _password.text,
    );
    // Em sucesso o status vira `authenticated`; fechamos esta rota para
    // revelar o app (já reconstruído pelo AuthGate).
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.auth,
      builder: (context, _) {
        final busy = widget.auth.busy;
        return AuthScaffold(
          title: 'Criar conta',
          subtitle: 'Cadastre-se para começar',
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: _name,
                  label: 'Nome',
                  icon: Icons.person_outline,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe seu nome'
                      : null,
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: _email,
                  label: 'E-mail',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: validateEmail,
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: _password,
                  label: 'Senha',
                  icon: Icons.lock_outline,
                  obscure: true,
                  validator: validatePassword,
                ),
                if (widget.auth.error != null) ...[
                  const SizedBox(height: 16),
                  AuthErrorBanner(message: widget.auth.error!),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Cadastrar'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Já tem conta? Entrar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
