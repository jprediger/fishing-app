import 'package:flutter/material.dart';

import '../main.dart';
import '../models/auth_user.dart';
import '../state/auth_controller.dart';
import 'edit_profile_screen.dart';

/// Tela "Eu" com o perfil real do pescador, vindo do [AuthController].
class ProfileScreen extends StatelessWidget {
  /// Opcional para manter compatibilidade com testes que montam a aba sem
  /// sessão; em produção sempre recebe o controller pelo `HomeShell`.
  final AuthController? auth;

  const ProfileScreen({super.key, this.auth});

  @override
  Widget build(BuildContext context) {
    final controller = auth;
    if (controller == null) return _buildContent(context, null);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildContent(context, controller.user),
    );
  }

  Widget _buildContent(BuildContext context, AuthUser? user) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(context, user),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatCard(label: 'Capturas', value: '0', icon: Icons.set_meal),
                SizedBox(width: 12),
                _StatCard(label: 'Pontos', value: '0', icon: Icons.place),
                SizedBox(width: 12),
                _StatCard(label: 'Saídas', value: '0', icon: Icons.sailing),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Atividade'),
          const _ProfileTile(
            icon: Icons.history,
            title: 'Histórico de pescarias',
          ),
          const _ProfileTile(
            icon: Icons.bookmark_border,
            title: 'Pontos salvos',
          ),
          const SizedBox(height: 12),
          const _SectionTitle('Conta'),
          _ProfileTile(
            icon: Icons.edit_outlined,
            title: 'Editar perfil',
            onTap: auth == null ? null : () => _openEdit(context),
          ),
          _ProfileTile(
            icon: Icons.logout,
            title: 'Sair',
            onTap: auth == null ? null : () => auth!.logout(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _openEdit(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => EditProfileScreen(auth: auth!)));
  }

  Widget _buildHeader(BuildContext context, AuthUser? user) {
    final name = user?.name ?? 'Pescador';
    final email = user?.email ?? '';
    final cs = Theme.of(context).colorScheme;
    // Brancos intencionais sobre gradiente de marca.
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.waterGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Meu perfil',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: auth == null ? null : () => _openEdit(context),
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: cs.surface,
                  child: const Icon(
                    Icons.person,
                    size: 52,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (email.isNotEmpty)
                Text(
                  email,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                ),
              if (user != null && user.isAdmin) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.role.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _ProfileTile({required this.icon, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              // brand accent stays fixed; surface text follows theme.
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          onTap: onTap,
        ),
      ),
    );
  }
}
