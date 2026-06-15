import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/api_config.dart';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil atualizado.')));
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickAvatar() async {
    widget.auth.clearError();
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;

    final ok = await widget.auth.updateAvatar(file);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil atualizada.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Editar perfil'),
      ),
      body: ListenableBuilder(
        listenable: widget.auth,
        builder: (context, _) {
          final busy = widget.auth.busy;
          final user = widget.auth.user;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Column(
                      children: [
                        _AvatarPreview(
                          avatarPath: user?.avatarPath,
                          token: widget.auth.token,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: busy ? null : _pickAvatar,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Trocar foto'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
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
                      backgroundColor: cs.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: busy
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimary,
                            ),
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

class _AvatarPreview extends StatelessWidget {
  final String? avatarPath;
  final String? token;

  const _AvatarPreview({required this.avatarPath, required this.token});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.waterGradient,
        border: Border.all(color: cs.surfaceContainerHighest, width: 2),
      ),
    );

    if (avatarPath == null || avatarPath!.isEmpty) {
      return placeholder;
    }

    return ClipOval(
      child: SizedBox(
        width: 88,
        height: 88,
        child: Image.network(
          _avatarUrl(avatarPath!),
          headers: token == null ? null : {'Authorization': 'Bearer $token'},
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => placeholder,
        ),
      ),
    );
  }

  String _avatarUrl(String relativePath) {
    final sanitized = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;
    return '${ApiConfig.baseUrl}/uploads/$sanitized';
  }
}
