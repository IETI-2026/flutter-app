import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/domain/entities/user.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_bloc.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_event.dart';
import 'package:flutter_app/presentation/pages/service_requests_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfilePage extends StatelessWidget {
  final User user;

  const ProfilePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  backgroundImage: user.profilePhotoUrl != null
                      ? NetworkImage(user.profilePhotoUrl!)
                      : null,
                  child: user.profilePhotoUrl == null
                      ? Text(
                          user.fullName.isNotEmpty
                              ? user.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 14),
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (user.phoneNumber != null &&
                    user.phoneNumber!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.phoneNumber!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Menu section
          Container(
            color: AppColors.white,
            child: Column(
              children: [
                _MenuItem(
                  icon: Icons.location_on_outlined,
                  label: 'Direcciones',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Próximamente')),
                    );
                  },
                ),
                const _Divider(),
                _MenuItem(
                  icon: Icons.list_alt_outlined,
                  label: 'Servicios solicitados',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ServiceRequestsPage(userId: user.id),
                      ),
                    );
                  },
                ),
                const _Divider(),
                _MenuItem(
                  icon: Icons.credit_card_outlined,
                  label: 'Métodos de pago',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Próximamente')),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Container(
            color: AppColors.white,
            child: Column(
              children: [
                _MenuItem(
                  icon: Icons.article_outlined,
                  label: 'Términos y condiciones',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Próximamente')),
                    );
                  },
                ),
                const _Divider(),
                _MenuItem(
                  icon: Icons.help_outline,
                  label: 'Ayuda',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Próximamente')),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Container(
            color: AppColors.white,
            child: _MenuItem(
              icon: Icons.logout,
              label: 'Cerrar sesión',
              iconColor: AppColors.error,
              labelColor: AppColors.error,
              showChevron: false,
              onTap: () => _confirmLogout(context),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<AuthBloc>().add(const LogoutEvent());
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (_) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;
  final bool showChevron;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? AppColors.textPrimary;
    final effectiveLabelColor = labelColor ?? AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: effectiveIconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: effectiveLabelColor,
                ),
              ),
            ),
            if (showChevron)
              const Icon(Icons.chevron_right, color: AppColors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 72),
      child: Divider(height: 1, color: AppColors.greyLight),
    );
  }
}
