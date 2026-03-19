import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/core/services/tenant_service.dart';
import 'package:flutter_app/core/services/theme_service.dart';
import 'package:flutter_app/core/services/websocket_service.dart';
import 'package:flutter_app/domain/entities/user.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_bloc.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_event.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_state.dart';
import 'package:flutter_app/presentation/bloc/location/location_cubit.dart';
import 'package:flutter_app/presentation/bloc/location/location_state.dart';
import 'package:flutter_app/presentation/pages/terms_and_conditions_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

const _orange = AppColors.primary;

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

  bool _wsInitialized = false;
  final List<Map<String, dynamic>> _newRequests = [];

  List<Map<String, dynamic>> _availableRequests = [];
  bool _loadingAvailable = false;

  List<String> _skills = [];
  bool _savingSkills = false;

  static const _allSkills = [
    'plomeria', 'electricidad', 'cerrajeria', 'gas', 'albanileria',
    'carpinteria', 'refrigeracion', 'tecnologia', 'jardineria', 'pintura',
    'limpieza', 'impermeabilizacion', 'techos', 'vidrieria', 'soldadura',
    'mantenimiento', 'mascotas', 'mudanza', 'otro',
  ];

  final _skillSearchController = TextEditingController();
  List<String> _filteredSkills = _allSkills;
  bool _showSkillDropdown = false;

  bool _isDark = false;

  void _onThemeChanged() {
    if (mounted) setState(() => _isDark = sl<ThemeService>().isDark);
  }

  Color get _bg => _isDark ? const Color(0xFF0F0F0F) : AppColors.backgroundLight;
  Color get _card => _isDark ? const Color(0xFF1C1C1C) : AppColors.white;
  Color get _cardAlt => _isDark ? const Color(0xFF252525) : AppColors.surfaceSoft;
  Color get _border => _isDark ? const Color(0xFF2E2E2E) : AppColors.greyLight;
  Color get _txtPri => _isDark ? Colors.white : AppColors.textPrimary;
  Color get _txtSec => _isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;
  Color get _appBarBg => _isDark ? const Color(0xFF111111) : AppColors.white;

  @override
  void initState() {
    super.initState();
    _locationCubit = sl<LocationCubit>()..fetchLocation();
    _initProfile();
    _isDark = sl<ThemeService>().isDark;
    sl<ThemeService>().addListener(_onThemeChanged);
  }

  Future<void> _initProfile() async {
    try {
      final response = await sl<Dio>().get('/users/me/provider-profile');
      final data = response.data;
      setState(() {
        _isAvailable = (data is Map ? data['isAvailable'] : null) ?? true;
        _skills = (data is Map && data['skills'] is List)
            ? List<String>.from(data['skills'] as List)
            : [];
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

  void _initWebSocket(String userId) {
    if (_wsInitialized) return;
    _wsInitialized = true;

    final wsService = sl<WebSocketService>();
    wsService.connect();

    wsService.onNewServiceRequest((data) {
      if (!mounted) return;
      final requestedSkills = (data['requestedSkills'] as List?)
              ?.map((s) => s.toString().toLowerCase())
              .toSet() ??
          {};
      final mySkills = _skills.map((s) => s.toLowerCase()).toSet();
      if (requestedSkills.isEmpty ||
          requestedSkills.intersection(mySkills).isNotEmpty) {
        setState(() {
          _newRequests.add(data);
        });
      }
    });

    // Wait a moment for the connection to establish before joining room
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        wsService.joinTechnicianRoom(userId, sl<TenantService>().tenantId);
      }
    });
  }

  Future<void> _addSkill(String skill) async {
    final trimmed = skill.trim();
    if (trimmed.isEmpty || _skills.contains(trimmed)) return;
    final updated = [..._skills, trimmed];
    setState(() {
      _skills = updated;
      _savingSkills = true;
    });
    try {
      await sl<Dio>().patch(
        '/users/me/provider-profile',
        data: {'skills': updated},
      );
    } catch (_) {
      if (mounted) setState(() => _skills = updated..remove(trimmed));
    } finally {
      if (mounted) setState(() => _savingSkills = false);
    }
  }

  Future<void> _removeSkill(String skill) async {
    final updated = _skills.where((s) => s != skill).toList();
    setState(() {
      _skills = updated;
      _savingSkills = true;
    });
    try {
      await sl<Dio>().patch(
        '/users/me/provider-profile',
        data: {'skills': updated},
      );
    } catch (_) {
      if (mounted) setState(() => _skills = [...updated, skill]);
    } finally {
      if (mounted) setState(() => _savingSkills = false);
    }
  }

  List<String> _filterSkills(String query) {
    final q = query.toLowerCase().trim();
    return _allSkills
        .where((s) => !_skills.contains(s) && s.contains(q))
        .toList();
  }

  void _onSkillSearchChanged(String query) {
    setState(() {
      _filteredSkills = _filterSkills(query);
      _showSkillDropdown = true;
    });
  }

  void _selectSkill(String skill) {
    _skillSearchController.clear();
    setState(() {
      _filteredSkills = _filterSkills('');
      _showSkillDropdown = false;
    });
    _addSkill(skill);
  }

  Widget _buildSkillsSelector() {
    final available = _filteredSkills.where((s) => !_skills.contains(s)).toList();
    final showList = _showSkillDropdown && available.isNotEmpty;

    return Column(
      children: [
        TextField(
          controller: _skillSearchController,
          style: GoogleFonts.poppins(fontSize: 14, color: _txtPri),
          onChanged: _onSkillSearchChanged,
          onTap: () {
            setState(() {
              _filteredSkills = _filterSkills(_skillSearchController.text);
              _showSkillDropdown = true;
            });
          },
          decoration: InputDecoration(
            hintText: 'Buscar habilidad...',
            hintStyle: GoogleFonts.poppins(fontSize: 13, color: _txtSec),
            prefixIcon: const Icon(Icons.search, color: _orange, size: 20),
            suffixIcon: _skillSearchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 18, color: _txtSec),
                    onPressed: () {
                      _skillSearchController.clear();
                      setState(() {
                        _filteredSkills = _filterSkills('');
                        _showSkillDropdown = false;
                      });
                    },
                  )
                : Icon(Icons.keyboard_arrow_down, color: _txtSec),
            filled: true,
            fillColor: _cardAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _orange.withValues(alpha: 0.6), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        if (showList)
          Container(
            constraints: BoxConstraints(maxHeight: min(available.length * 48.0, 200)),
            decoration: BoxDecoration(
              color: _cardAlt,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: available.length,
              itemBuilder: (context, i) {
                final skill = available[i];
                final query = _skillSearchController.text.toLowerCase();
                return InkWell(
                  onTap: () => _selectSkill(skill),
                  splashColor: _orange.withValues(alpha: 0.08),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: i < available.length - 1
                          ? Border(bottom: BorderSide(color: _border, width: 0.5))
                          : null,
                    ),
                    alignment: Alignment.centerLeft,
                    child: _buildHighlightedSkill(skill, query),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildHighlightedSkill(String skill, String query) {
    if (query.isEmpty) {
      return Text(skill, style: GoogleFonts.poppins(fontSize: 14, color: _txtPri));
    }
    final idx = skill.indexOf(query);
    if (idx == -1) {
      return Text(skill, style: GoogleFonts.poppins(fontSize: 14, color: _txtSec));
    }
    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(fontSize: 14, color: _txtSec),
        children: [
          if (idx > 0) TextSpan(text: skill.substring(0, idx)),
          TextSpan(
            text: skill.substring(idx, idx + query.length),
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: _orange),
          ),
          if (idx + query.length < skill.length)
            TextSpan(text: skill.substring(idx + query.length)),
        ],
      ),
    );
  }

  Future<void> _loadAvailableRequests(String userId) async {
    setState(() => _loadingAvailable = true);
    try {
      final response = await sl<Dio>().get(
        '/service-requests/available/$userId',
      );
      final data = response.data;
      if (mounted) {
        setState(() {
          _availableRequests = (data as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } catch (_) {
      // keep previous list on error
    } finally {
      if (mounted) setState(() => _loadingAvailable = false);
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

  Future<void> _acceptRequest(
    String requestId,
    String technicianId,
  ) async {
    try {
      await sl<Dio>().patch(
        '/service-requests/$requestId/accept',
        data: {'technicianUserId': technicianId},
      );
      if (mounted) {
        setState(() {
          _newRequests.removeWhere((r) => r['id']?.toString() == requestId);
          _availableRequests.removeWhere(
            (r) => r['id']?.toString() == requestId,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Solicitud aceptada',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data is Map<String, dynamic>
            ? e.response?.data['message']?.toString()
            : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg ?? 'Error al aceptar la solicitud',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _showNotificationsPanel(BuildContext context, String technicianId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => _NotificationsPanel(
          requests: List.from(_newRequests),
          skills: List.from(_skills),
          technicianId: technicianId,
          scrollController: scrollController,
          onAccept: (requestId) async {
            Navigator.of(context).pop();
            await _acceptRequest(requestId, technicianId);
          },
          onDismiss: (requestId) {
            setState(() {
              _newRequests.removeWhere(
                (r) => r['id']?.toString() == requestId,
              );
            });
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    sl<ThemeService>().removeListener(_onThemeChanged);
    _locationCubit.close();
    _skillSearchController.dispose();
    if (_wsInitialized) {
      sl<WebSocketService>().offNewServiceRequest();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_profileChecked) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _orange)),
      );
    }
    if (!_hasProfile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/provider-onboarding');
        }
      });
      return Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _orange)),
      );
    }

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthLoading || state is AuthInitial) {
          return Scaffold(
            backgroundColor: _bg,
            body: Center(child: CircularProgressIndicator(color: _orange)),
          );
        }

        if (state is! Authenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
          });
          return Scaffold(
            backgroundColor: _bg,
            body: Center(child: CircularProgressIndicator(color: _orange)),
          );
        }
        final user = state.user;

        if (!_wsInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _initWebSocket(user.id);
          });
        }

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _appBarBg,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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
            iconTheme: IconThemeData(color: _txtPri),
            actions: [
              _togglingAvailability
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _orange,
                        ),
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
                icon: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: _txtPri,
                ),
                tooltip: 'Pagos',
                onPressed: () {
                  Navigator.pushNamed(context, '/provider-payments');
                },
              ),
            ],
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildHomeTab(user),
              _buildSolicitudesTab(user),
              _buildComingSoonTab(Icons.work_outline, 'Activos'),
              _buildProfileTab(user),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (i) {
              setState(() => _selectedIndex = i);
              if (i == 1) _loadAvailableRequests(user.id);
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: _appBarBg,
            selectedItemColor: _orange,
            unselectedItemColor: const Color(0xFF555555),
            selectedLabelStyle: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
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
            decoration: BoxDecoration(
              color: _card,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // "Modo Profesional" badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: _orange.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified, size: 12, color: _orange),
                          const SizedBox(width: 5),
                          Text(
                            'Modo Profesional',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: _orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Notification bell with optional pop-up label
                    GestureDetector(
                      onTap: () =>
                          _showNotificationsPanel(context, user.id),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (_newRequests.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _orange.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                'Tienes camellos disponibles',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: _orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                Icons.notifications_outlined,
                                color: _txtPri,
                                size: 24,
                              ),
                              if (_newRequests.isNotEmpty)
                                Positioned(
                                  top: -3,
                                  right: -3,
                                  child: Container(
                                    width: 9,
                                    height: 9,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '¡Hola, ${user.fullName.split(' ').first}! 👋',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _txtPri,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isAvailable ? AppColors.success : _txtSec,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _isAvailable
                          ? 'Disponible para trabajar'
                          : 'No disponible',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: _isAvailable ? AppColors.success : _txtSec,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                BlocBuilder<LocationCubit, LocationState>(
                  bloc: _locationCubit,
                  builder: (context, locationState) {
                    if (locationState is LocationLoaded) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 13,
                            color: _orange,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              locationState.formattedAddress,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: _txtSec,
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    if (locationState is LocationLoading) {
                      return const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _orange,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        '4.8',
                        'Calificación',
                        Icons.star_rounded,
                        AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        '0',
                        'Servicios',
                        Icons.check_circle_rounded,
                        AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        '\$0',
                        'Ganancias',
                        Icons.attach_money_rounded,
                        _orange,
                      ),
                    ),
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _txtPri,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _newRequests.isNotEmpty ? _orange : _cardAlt,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_newRequests.length}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_newRequests.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 48,
                            color: _txtSec.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No hay solicitudes pendientes',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: _txtSec,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Recibirás notificaciones cuando haya nuevas solicitudes',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: _txtSec.withValues(alpha: 0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 280,
                      child: ListView.builder(
                        itemCount: _newRequests.length,
                        itemBuilder: (context, index) =>
                            _buildRequestPreviewCard(
                          _newRequests[index],
                          user.id,
                        ),
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _txtPri,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.work_outline,
                          size: 48,
                          color: _txtSec.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No tienes servicios activos',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: _txtSec,
                          ),
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

  Widget _buildRequestPreviewCard(Map<String, dynamic> request, String userId) {
    final problema = request['problema']?.toString() ?? 'Sin descripción';
    final skills = (request['requestedSkills'] as List?)
            ?.map((s) => s.toString())
            .take(2)
            .join(', ') ??
        '';
    final requestId = request['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            problema,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: _txtPri,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (skills.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              skills,
              style: GoogleFonts.poppins(fontSize: 11, color: _orange),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _acceptRequest(requestId, userId),
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Aceptar',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
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
                              user.fullName.isNotEmpty
                                  ? user.fullName[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.poppins(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: _orange,
                              ),
                            )
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _orange,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: _card, width: 2),
                      ),
                      child: Text(
                        'PRO',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  user.fullName,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _txtPri,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: GoogleFonts.poppins(fontSize: 13, color: _txtSec),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: (_isAvailable ? AppColors.success : _txtSec)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (_isAvailable ? AppColors.success : _txtSec)
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _isAvailable ? AppColors.success : _txtSec,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isAvailable ? 'Disponible' : 'No disponible',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
            child: Column(
              children: [
                _ProMenuItem(
                  icon: Icons.dark_mode_outlined,
                  label: _isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
                  showChevron: false,
                  onTap: () => sl<ThemeService>().toggle(),
                ),
                const _ProDivider(),
                _ProMenuItem(
                  icon: Icons.check_circle_outline,
                  label: 'Servicios',
                  onTap: () => _showComingSoon(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Habilidades
          GestureDetector(
            onTap: () => setState(() => _showSkillDropdown = false),
            behavior: HitTestBehavior.translucent,
            child: Container(
              color: _card,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Habilidades',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _txtPri,
                        ),
                      ),
                      if (_savingSkills)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _orange,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildSkillsSelector(),
                  if (_skills.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _skills
                          .map(
                            (s) => Chip(
                              label: Text(
                                s,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: _orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              backgroundColor: _orange.withValues(alpha: 0.12),
                              side: BorderSide(color: _orange.withValues(alpha: 0.35)),
                              deleteIconColor: _orange,
                              onDeleted: () => _removeSkill(s),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TermsAndConditionsPage(),
                      ),
                    );
                  },
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
        titlePadding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Cerrar sesión',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: _txtPri,
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: Icon(Icons.close, color: _txtSec),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que quieres cerrar sesión?',
          style: GoogleFonts.poppins(color: _txtSec),
        ),
        actions: [
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
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Cerrar sesión', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  // ── COMING SOON ─────────────────────────────────────────────────────────────

  Widget _buildSolicitudesTab(User user) {
    if (_loadingAvailable) {
      return const Center(
        child: CircularProgressIndicator(color: _orange),
      );
    }
    if (_availableRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 56,
              color: _txtSec.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 14),
            Text(
              'No hay solicitudes disponibles',
              style: GoogleFonts.poppins(fontSize: 15, color: _txtSec),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _availableRequests.length,
      itemBuilder: (context, index) {
        final r = _availableRequests[index];
        final problema = r['problema']?.toString() ?? 'Sin descripción';
        final skills = (r['requestedSkills'] as List?)
                ?.map((s) => s.toString())
                .toList() ??
            [];
        final urgency = r['urgency']?.toString();
        final address = r['addressText']?.toString();
        final requestId = r['id']?.toString() ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      problema,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: _txtPri,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (urgency != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: urgency == 'HIGH'
                            ? Colors.red.withValues(alpha: 0.15)
                            : _orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        urgency,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: urgency == 'HIGH' ? Colors.red : _orange,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (skills.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: skills
                      .map(
                        (s) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _orange.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            s,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: _orange,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (address != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: _txtSec,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: _txtSec,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _acceptRequest(requestId, user.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Aceptar',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
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
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: color,
            ),
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

// ── NOTIFICATIONS PANEL ──────────────────────────────────────────────────────

class _NotificationsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final List<String> skills;
  final String technicianId;
  final ScrollController scrollController;
  final void Function(String requestId) onAccept;
  final void Function(String requestId) onDismiss;

  const _NotificationsPanel({
    required this.requests,
    required this.skills,
    required this.technicianId,
    required this.scrollController,
    required this.onAccept,
    required this.onDismiss,
  });

  List<Map<String, dynamic>> get _filtered {
    if (skills.isEmpty) return requests;
    final mySkills = skills.map((s) => s.toLowerCase()).toSet();
    return requests.where((r) {
      final rs = (r['requestedSkills'] as List?)
              ?.map((s) => s.toString().toLowerCase())
              .toSet() ??
          {};
      return rs.isEmpty || rs.intersection(mySkills).isNotEmpty;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelBg = isDark ? const Color(0xFF1C1C1C) : AppColors.white;
    final itemBg = isDark ? const Color(0xFF252525) : AppColors.surfaceSoft;
    final borderColor = isDark ? const Color(0xFF2E2E2E) : AppColors.greyLight;
    final txtPri = isDark ? Colors.white : AppColors.textPrimary;
    final txtSec = isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;
    final filtered = _filtered;
    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_active,
                  color: _orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Solicitudes disponibles',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: txtPri,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${filtered.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: txtSec.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No hay solicitudes nuevas',
                      style: GoogleFonts.poppins(fontSize: 14, color: txtSec),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final r = filtered[index];
                  final requestId = r['id']?.toString() ?? '';
                  final problema =
                      r['problema']?.toString() ?? 'Sin descripción';
                  final skills = (r['requestedSkills'] as List?)
                          ?.map((s) => s.toString())
                          .toList() ??
                      [];
                  final address = r['addressText']?.toString() ?? '';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: itemBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.build_outlined,
                                color: _orange,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    problema,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: txtPri,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (address.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 12,
                                          color: txtSec,
                                        ),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            address,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: txtSec,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (skills.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: skills
                                .take(3)
                                .map(
                                  (skill) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _orange.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Text(
                                      skill,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: _orange,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => onDismiss(requestId),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: txtSec,
                                  side: BorderSide(color: borderColor),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Ignorar',
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: requestId.isNotEmpty
                                    ? () => onAccept(requestId)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _orange,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Aceptar',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultIconColor = iconColor ?? _orange;
    final defaultLabelColor = labelColor ?? (isDark ? Colors.white : AppColors.textPrimary);
    final chevronColor = isDark ? const Color(0xFF9E9E9E) : AppColors.grey;
    final effectiveIconColor = defaultIconColor;
    final effectiveLabelColor = defaultLabelColor;

    return InkWell(
      onTap: onTap,
      splashColor: _orange.withValues(alpha: 0.06),
      highlightColor: _orange.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
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

class _ProDivider extends StatelessWidget {
  const _ProDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? const Color(0xFF2E2E2E) : AppColors.greyLight;
    return Padding(
      padding: const EdgeInsets.only(left: 72),
      child: Divider(height: 1, color: dividerColor),
    );
  }
}
