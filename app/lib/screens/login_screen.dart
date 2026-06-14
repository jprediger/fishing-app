import 'package:flutter/material.dart';

import '../main.dart';
import '../state/auth_controller.dart';
import 'auth_widgets.dart';
import 'register_screen.dart';

/// Tela de login. Valida os campos localmente e delega ao [AuthController].
class LoginScreen extends StatefulWidget {
  final AuthController auth;

  const LoginScreen({super.key, required this.auth});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    widget.auth.clearError();
    if (!_formKey.currentState!.validate()) return;
    await widget.auth.login(_email.text.trim(), _password.text);
  }

  void _goToRegister() {
    widget.auth.clearError();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RegisterScreen(auth: widget.auth)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.auth,
      builder: (context, _) {
        final busy = widget.auth.busy;
        return AuthScaffold(
          title: 'Bem-vindo de volta',
          subtitle: 'Entre para continuar pescando',
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Informe sua senha'
                      : null,
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
                      : const Text('Entrar'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: busy ? null : _goToRegister,
                  child: const Text('Não tem conta? Cadastre-se'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
