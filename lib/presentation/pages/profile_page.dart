import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/core/services/theme_service.dart';
import 'package:flutter_app/core/utils/name_utils.dart';
import 'package:flutter_app/domain/entities/user.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_bloc.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_event.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_state.dart';
import 'package:flutter_app/presentation/pages/more_information_page.dart';
import 'package:flutter_app/presentation/pages/service_requests_page.dart';
import 'package:flutter_app/presentation/widgets/profile_photo_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfilePage extends StatefulWidget {
  final User user;

  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _isDark = sl<ThemeService>().isDark;
    sl<ThemeService>().addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    sl<ThemeService>().removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() => _isDark = sl<ThemeService>().isDark);
  }

  Color get _bg => _isDark ? const Color(0xFF1C1C1C) : AppColors.white;
  Color get _divider => _isDark ? const Color(0xFF2E2E2E) : AppColors.greyLight;
  Color get _txtPri => _isDark ? Colors.white : AppColors.textPrimary;
  Color get _txtSec =>
      _isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current is AuthError ||
          (current is Authenticated && previous is! Authenticated),
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final user = state is Authenticated ? state.user : widget.user;
        final isUploading = state is AuthLoading;
        return _buildContent(context, user, isUploading);
      },
    );
  }

  Widget _buildContent(BuildContext context, User user, bool isUploading) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            color: _bg,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            child: Column(
              children: [
                Stack(
                  children: [
                    ProfilePhotoWidget(
                      photoUrl: user.profilePhotoUrl,
                      name: user.fullName,
                      radius: 42,
                    ),
                    if (isUploading)
                      const Positioned.fill(
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.black45,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  shortName(user.fullName),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _txtPri,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(fontSize: 13, color: _txtSec),
                ),
                if (user.phoneNumber != null &&
                    user.phoneNumber!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.phoneNumber!,
                    style: TextStyle(fontSize: 13, color: _txtSec),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Menu section
          Container(
            color: _bg,
            child: Column(
              children: [
                _MenuItem(
                  icon: Icons.dark_mode_outlined,
                  label: _isDark
                      ? 'Cambiar a modo claro'
                      : 'Cambiar a modo oscuro',
                  showChevron: false,
                  isDark: _isDark,
                  onTap: () => sl<ThemeService>().toggle(),
                ),
                _Divider(color: _divider),
                _MenuItem(
                  icon: Icons.location_on_outlined,
                  label: 'Direcciones',
                  isDark: _isDark,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Próximamente')),
                    );
                  },
                ),
                _Divider(color: _divider),
                _MenuItem(
                  icon: Icons.list_alt_outlined,
                  label: 'Camellos solicitados',
                  isDark: _isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ServiceRequestsPage(userId: user.id),
                      ),
                    );
                  },
                ),
                _Divider(color: _divider),
                _MenuItem(
                  icon: Icons.credit_card_outlined,
                  label: 'Métodos de pago',
                  isDark: _isDark,
                  onTap: () {
                    final route = user.isProvider
                        ? '/provider-payments'
                        : '/client-payments';
                    Navigator.pushNamed(context, route);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Container(
            color: _bg,
            child: Column(
              children: [
                _MenuItem(
                  icon: Icons.info_outline,
                  label: 'Más información',
                  isDark: _isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MoreInformationPage(),
                      ),
                    );
                  },
                ),
                _Divider(color: _divider),
                _MenuItem(
                  icon: Icons.help_outline,
                  label: 'Ayuda',
                  isDark: _isDark,
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
            color: _bg,
            child: _MenuItem(
              icon: Icons.logout,
              label: 'Cerrar sesión',
              iconColor: AppColors.error,
              labelColor: AppColors.error,
              showChevron: false,
              isDark: _isDark,
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
        backgroundColor: _bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cerrar sesión',
          style: TextStyle(color: _txtPri, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Deseas salir de la aplicación?',
          style: TextStyle(color: _txtSec),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _txtSec,
                    side: BorderSide(color: _divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    context.read<AuthBloc>().add(const LogoutEvent());
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/auth-role',
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
                  child: const Text('Aceptar'),
                ),
              ),
            ],
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
  final bool isDark;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    this.iconColor,
    this.labelColor,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? AppColors.primary;
    final effectiveLabelColor =
        labelColor ?? (isDark ? Colors.white : AppColors.textPrimary);
    final chevronColor = isDark ? const Color(0xFF9E9E9E) : AppColors.grey;

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
                color: effectiveIconColor.withValues(alpha: 0.08),
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
              Icon(Icons.chevron_right, color: chevronColor, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;

  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 72),
      child: Divider(height: 1, color: color),
    );
  }
}
