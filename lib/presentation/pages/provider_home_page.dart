import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/domain/entities/user.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_bloc.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_event.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_state.dart';
import 'package:flutter_app/presentation/bloc/location/location_cubit.dart';
import 'package:flutter_app/presentation/bloc/location/location_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Paleta premium negro + naranja ──────────────────────────────────────────
const _bg       = Color(0xFF0F0F0F);
const _card     = Color(0xFF1C1C1C);
const _cardAlt  = Color(0xFF252525);
const _border   = Color(0xFF2E2E2E);
const _txtPri   = Colors.white;
const _txtSec   = Color(0xFF9E9E9E);
const _orange   = AppColors.primary;
// ─────────────────────────────────────────────────────────────────────────────

class ProviderHomePage extends StatefulWidget {
  const ProviderHomePage({super.key});

  @override
  State<ProviderHomePage> createState() => _ProviderHomePageState();
}

class _ProviderHomePageState extends State<ProviderHomePage> {
  late final LocationCubit _locationCubit;

  bool _profileChecked = false;
  bool _hasProfile = false;
  bool _isAvailable = true;
  bool _togglingAvailability = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _locationCubit = sl<LocationCubit>()..fetchLocation();
    _initProfile();
  }

  Future<void> _initProfile() async {
    try {
      final response = await sl<Dio>().get('/users/me/provider-profile');
      final data = response.data;
      setState(() {
        _isAvailable = (data is Map ? data['isAvailable'] : null) ?? true;
        _hasProfile = true;
        _profileChecked = true;
      });
    } on DioException catch (e) {
      setState(() {
        _hasProfile = e.response?.statusCode != 404;
        _profileChecked = true;
      });
    } catch (_) {
      setState(() {
        _hasProfile = true;
        _profileChecked = true;
      });
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    setState(() {
      _isAvailable = value;
      _togglingAvailability = true;
    });
    try {
      await sl<Dio>().patch(
        '/users/me/provider-profile',
        data: {'isAvailable': value},
      );
    } catch (_) {
      if (mounted) setState(() => _isAvailable = !value);
    } finally {
      if (mounted) setState(() => _togglingAvailability = false);
    }
  }

  @override
  void dispose() {
    _locationCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_profileChecked) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _orange)),
      );
    }
    if (!_hasProfile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pushReplacementNamed(context, '/provider-onboarding');
      });
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _orange)),
      );
    }

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return const Scaffold(
            backgroundColor: _bg,
            body: Center(child: CircularProgressIndicator(color: _orange)),
          );
        }
        final user = state.user;

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: const Color(0xFF111111),
            elevation: 0,
            centerTitle: false,
            titleSpacing: 16,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'CameYo',
                  style: GoogleFonts.poppins(
                    color: _txtPri,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _orange,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    'PRO',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            iconTheme: const IconThemeData(color: _txtPri),
            actions: [
              BlocBuilder<LocationCubit, LocationState>(
                bloc: _locationCubit,
                builder: (context, locationState) {
                  if (locationState is LocationLoaded) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, size: 14, color: _orange),
                          const SizedBox(width: 2),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 100),
                            child: Text(
                              locationState.formattedAddress,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: _txtSec),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (locationState is LocationLoading) {
                    return const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _orange),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              _togglingAvailability
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _orange),
                      ),
                    )
                  : Switch(
                      value: _isAvailable,
                      onChanged: _toggleAvailability,
                      activeTrackColor: _orange,
                      activeThumbColor: Colors.white,
                      inactiveTrackColor: _border,
                      inactiveThumbColor: _txtSec,
                    ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: _txtPri),
                onPressed: () {},
              ),
            ],
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildHomeTab(user),
              _buildComingSoonTab(Icons.list_alt_outlined, 'Solicitudes'),
              _buildComingSoonTab(Icons.work_outline, 'Activos'),
              _buildProfileTab(user),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (i) => setState(() => _selectedIndex = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: const Color(0xFF111111),
            selectedItemColor: _orange,
            unselectedItemColor: const Color(0xFF555555),
            selectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Inicio',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.list_alt_outlined),
                activeIcon: Icon(Icons.list_alt),
                label: 'Solicitudes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.work_outline),
                activeIcon: Icon(Icons.work),
                label: 'Activos',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
            ],
          ),
        );
      },
    );
  }

  // ── HOME TAB ────────────────────────────────────────────────────────────────

  Widget _buildHomeTab(User user) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "Modo Profesional" badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _orange.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified, size: 12, color: _orange),
                      const SizedBox(width: 5),
                      Text(
                        'Modo Profesional',
                        style: GoogleFonts.poppins(
                          fontSize: 11, color: _orange, fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '¡Hola, ${user.fullName.split(' ').first}! 👋',
                  style: GoogleFonts.poppins(
                    fontSize: 24, fontWeight: FontWeight.bold, color: _txtPri,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: _isAvailable ? AppColors.success : _txtSec,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _isAvailable ? 'Disponible para trabajar' : 'No disponible',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: _isAvailable ? AppColors.success : _txtSec,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _buildStatCard('4.8', 'Calificación', Icons.star_rounded, AppColors.secondary)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildStatCard('0', 'Servicios', Icons.check_circle_rounded, AppColors.success)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildStatCard('\$0', 'Ganancias', Icons.attach_money_rounded, _orange)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Solicitudes pendientes
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Solicitudes Pendientes',
                        style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.bold, color: _txtPri,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '0',
                          style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: _txtSec.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'No hay solicitudes pendientes',
                          style: GoogleFonts.poppins(fontSize: 13, color: _txtSec),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Recibirás notificaciones cuando haya nuevas solicitudes',
                          style: GoogleFonts.poppins(fontSize: 11, color: _txtSec.withValues(alpha: 0.6)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Servicios activos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Servicios Activos',
                    style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.bold, color: _txtPri,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.work_outline, size: 48, color: _txtSec.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'No tienes servicios activos',
                          style: GoogleFonts.poppins(fontSize: 13, color: _txtSec),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── PROFILE TAB ─────────────────────────────────────────────────────────────

  Widget _buildProfileTab(User user) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            color: _card,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: _orange.withValues(alpha: 0.15),
                      backgroundImage: user.profilePhotoUrl != null
                          ? NetworkImage(user.profilePhotoUrl!)
                          : null,
                      child: user.profilePhotoUrl == null
                          ? Text(
                              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                              style: GoogleFonts.poppins(
                                fontSize: 34, fontWeight: FontWeight.bold, color: _orange,
                              ),
                            )
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _orange,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: _card, width: 2),
                      ),
                      child: Text(
                        'PRO',
                        style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  user.fullName,
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _txtPri),
                ),
                const SizedBox(height: 4),
                Text(user.email, style: GoogleFonts.poppins(fontSize: 13, color: _txtSec)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: (_isAvailable ? AppColors.success : _txtSec).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (_isAvailable ? AppColors.success : _txtSec).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          color: _isAvailable ? AppColors.success : _txtSec,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isAvailable ? 'Disponible' : 'No disponible',
                        style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: _isAvailable ? AppColors.success : _txtSec,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Sección 1
          Container(
            color: _card,
            child: _ProMenuItem(
              icon: Icons.check_circle_outline,
              label: 'Servicios',
              onTap: () => _showComingSoon(context),
            ),
          ),

          const SizedBox(height: 12),

          // Sección 2
          Container(
            color: _card,
            child: Column(
              children: [
                _ProMenuItem(
                  icon: Icons.article_outlined,
                  label: 'Términos y condiciones',
                  onTap: () => _showComingSoon(context),
                ),
                const _ProDivider(),
                _ProMenuItem(
                  icon: Icons.help_outline,
                  label: 'Ayuda',
                  onTap: () => _showComingSoon(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Cerrar sesión
          Container(
            color: _card,
            child: _ProMenuItem(
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

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Próximamente disponible', style: GoogleFonts.poppins()),
        backgroundColor: _card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cerrar sesión',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _txtPri),
        ),
        content: Text(
          '¿Estás seguro de que quieres cerrar sesión?',
          style: GoogleFonts.poppins(color: _txtSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancelar', style: GoogleFonts.poppins(color: _txtSec)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<AuthBloc>().add(const LogoutEvent());
              Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Cerrar sesión', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  // ── COMING SOON ─────────────────────────────────────────────────────────────

  Widget _buildComingSoonTab(IconData icon, String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: _txtSec.withValues(alpha: 0.3)),
          const SizedBox(height: 14),
          Text(
            '$label próximamente',
            style: GoogleFonts.poppins(fontSize: 15, color: _txtSec),
          ),
        ],
      ),
    );
  }

  // ── STAT CARD ────────────────────────────────────────────────────────────────

  Widget _buildStatCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: _cardAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 10, color: _txtSec),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── SHARED WIDGETS ───────────────────────────────────────────────────────────

class _ProMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;
  final bool showChevron;

  const _ProMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? _orange;
    final effectiveLabelColor = labelColor ?? _txtPri;

    return InkWell(
      onTap: onTap,
      splashColor: _orange.withValues(alpha: 0.06),
      highlightColor: _orange.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: effectiveIconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: effectiveIconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w500, color: effectiveLabelColor,
                ),
              ),
            ),
            if (showChevron) const Icon(Icons.chevron_right, color: _txtSec, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ProDivider extends StatelessWidget {
  const _ProDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 72),
      child: Divider(height: 1, color: _border),
    );
  }
}
