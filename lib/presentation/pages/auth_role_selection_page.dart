import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/presentation/models/auth_entry_role.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

/// Paso inicial: el usuario elige si entra como cliente o profesional.
class AuthRoleSelectionPage extends StatelessWidget {
  const AuthRoleSelectionPage({super.key});

  void _goToLogin(BuildContext context, AuthEntryRole role) {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, '/login', arguments: role);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        color: AppColors.backgroundLight,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 28),
                FadeInDown(
                  child: Column(
                    children: [
                      _LogoBadge(),
                      const SizedBox(height: 28),
                      Text(
                        '¿Quién eres?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Elige cómo usar CameYo. Podrás cambiar de perfil más adelante si lo necesitas.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          height: 1.45,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                FadeInUp(
                  delay: const Duration(milliseconds: 120),
                  child: _RoleChoiceCard(
                    role: AuthEntryRole.client,
                    onTap: () => _goToLogin(context, AuthEntryRole.client),
                  ),
                ),
                const SizedBox(height: 16),
                FadeInUp(
                  delay: const Duration(milliseconds: 220),
                  child: _RoleChoiceCard(
                    role: AuthEntryRole.provider,
                    onTap: () => _goToLogin(context, AuthEntryRole.provider),
                  ),
                ),
                const SizedBox(height: 32),
                FadeInUp(
                  delay: const Duration(milliseconds: 320),
                  child: Text(
                    'Tu elección personaliza textos y el enfoque de inicio de sesión o registro.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Hero(
        tag: 'logo',
        child: Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Image.asset('logo-ieti.jpeg', fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleChoiceCard extends StatelessWidget {
  const _RoleChoiceCard({
    required this.role,
    required this.onTap,
  });

  final AuthEntryRole role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = role.heroGradientColors;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        colors[1].withValues(alpha: 0.95),
        colors[2].withValues(alpha: 0.88),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: role.accent.withValues(alpha: 0.15),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: role.accent.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    role.icon,
                    size: 30,
                    color: role.accentDeep,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.shortLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        role.valueProposition,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: AppColors.white.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
