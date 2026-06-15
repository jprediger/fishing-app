import 'package:flutter/material.dart';

import '../main.dart';

/// Regex simples de e-mail (suficiente para feedback no cliente; o backend
/// faz a validação definitiva).
final RegExp _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Valida e-mail: obrigatório e com formato plausível.
String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Informe seu e-mail';
  if (!_emailRegExp.hasMatch(v)) return 'E-mail inválido';
  return null;
}

/// Valida senha espelhando o backend: mínimo de 8 caracteres.
String? validatePassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return 'Informe uma senha';
  if (v.length < 8) return 'A senha deve ter ao menos 8 caracteres';
  return null;
}

/// Estrutura comum das telas de autenticação: cabeçalho com gradiente de água
/// e um cartão branco com o formulário.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // O gradiente preenche toda a tela; o conteúdo rola e fica centralizado
      // verticalmente quando sobra espaço.
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.waterGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brancos intencionais sobre gradiente de marca.
                      const Icon(Icons.set_meal, size: 64, color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Campo de texto padronizado para os formulários de autenticação.
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Banner de erro vermelho usado abaixo dos formulários.
class AuthErrorBanner extends StatelessWidget {
  final String message;

  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.error),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
