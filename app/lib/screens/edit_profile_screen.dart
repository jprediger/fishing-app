import 'package:flutter/material.dart';

import '../main.dart';
import '../state/auth_controller.dart';
import 'auth_widgets.dart';

/// Edição do perfil do usuário logado (nome e, opcionalmente, senha).
/// Persiste via `PUT /api/users/me` através do [AuthController].
class EditProfileScreen extends StatefulWidget {
  final AuthController auth;

  const EditProfileScreen({super.key, required this.auth});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.auth.user?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    widget.auth.clearError();
    if (!_formKey.currentState!.validate()) return;
    final password = _password.text.isEmpty ? null : _password.text;
    final ok = await widget.auth.updateProfile(
      name: _name.text.trim(),
      password: password,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado.')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Editar perfil'),
      ),
      body: ListenableBuilder(
        listenable: widget.auth,
        builder: (context, _) {
          final busy = widget.auth.busy;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
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
                    controller: _password,
                    label: 'Nova senha (opcional)',
                    icon: Icons.lock_outline,
                    obscure: true,
                    // Só valida o tamanho quando o usuário digita algo.
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      return v.length < 8
                          ? 'A senha deve ter ao menos 8 caracteres'
                          : null;
                    },
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
                        : const Text('Salvar'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
