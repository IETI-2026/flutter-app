import 'dart:async';
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
import 'package:flutter_app/presentation/pages/more_information_page.dart';
import 'package:flutter_app/presentation/pages/service_map_page.dart';
import 'package:flutter_app/presentation/widgets/profile_photo_widget.dart';
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
  OverlayEntry? _notificationOverlay;

  List<Map<String, dynamic>> _availableRequests = [];
  bool _loadingAvailable = false;

  List<Map<String, dynamic>> _assignedRequests = [];
  bool _loadingAssigned = false;
  bool _assignedInitialized = false;

  int _servicesCount = 0;

  List<String> _skills = [];
  bool _savingSkills = false;

  static const _allSkills = [
    'plomeria',
    'electricidad',
    'cerrajeria',
    'gas',
    'albanileria',
    'carpinteria',
    'refrigeracion',
    'tecnologia',
    'jardineria',
    'pintura',
    'limpieza',
    'impermeabilizacion',
    'techos',
    'vidrieria',
    'soldadura',
    'mantenimiento',
    'mascotas',
    'mudanza',
    'otro',
  ];

  final _skillSearchController = TextEditingController();
  List<String> _filteredSkills = _allSkills;
  bool _showSkillDropdown = false;

  bool _isDark = false;

  void _onThemeChanged() {
    if (mounted) setState(() => _isDark = sl<ThemeService>().isDark);
  }

  Color get _bg =>
      _isDark ? const Color(0xFF0F0F0F) : AppColors.backgroundLight;
  Color get _card => _isDark ? const Color(0xFF1C1C1C) : AppColors.white;
  Color get _cardAlt =>
      _isDark ? const Color(0xFF252525) : AppColors.surfaceSoft;
  Color get _border => _isDark ? const Color(0xFF2E2E2E) : AppColors.greyLight;
  Color get _txtPri => _isDark ? Colors.white : AppColors.textPrimary;
  Color get _txtSec =>
      _isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;
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
      final results = await Future.wait([
        sl<Dio>().get('/users/me/provider-profile'),
        sl<Dio>().get('/users/me'),
      ]);
      final profileData = results[0].data;
      final meData = results[1].data;
      setState(() {
        _isAvailable =
            (profileData is Map ? profileData['isAvailable'] : null) ?? true;
        _skills = (profileData is Map && profileData['skills'] is List)
            ? List<String>.from(profileData['skills'] as List)
            : [];
        _servicesCount =
            (meData is Map ? meData['servicesCount'] as int? : null) ?? 0;
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
    wsService.connect(
      technicianId: userId,
      tenantId: sl<TenantService>().tenantId,
    );

    wsService.onNewServiceRequest((data) {
      if (!mounted) return;
      final requestedSkills =
          (data['requestedSkills'] as List?)
              ?.map((s) => s.toString().toLowerCase())
              .toSet() ??
          {};
      final mySkills = _skills.map((s) => s.toLowerCase()).toSet();
      if (requestedSkills.isEmpty ||
          requestedSkills.intersection(mySkills).isNotEmpty) {
        setState(() {
          _newRequests.add(data);
        });
        _showCamelloNotification();
      }
    });

    wsService.onTechnicianStatsUpdated((data) {
      if (!mounted) return;
      final count = data['servicesCount'];
      if (count is int) setState(() => _servicesCount = count);
    });

    wsService.onServiceStatusUpdated((data) {
      if (!mounted) return;
      final requestId = data['requestId']?.toString() ?? '';
      final newStatus = data['status']?.toString() ?? '';
      if (requestId.isEmpty || newStatus.isEmpty) return;

      setState(() {
        if (newStatus == 'COMPLETED' || newStatus == 'CANCELLED') {
          _assignedRequests.removeWhere(
            (r) => r['id']?.toString() == requestId,
          );
        } else {
          final idx = _assignedRequests.indexWhere(
            (r) => r['id']?.toString() == requestId,
          );
          if (idx >= 0) {
            _assignedRequests[idx] = Map<String, dynamic>.from(
              _assignedRequests[idx],
            )..['status'] = newStatus;
          }
        }
      });
    });
  }

  void _showCamelloNotification() {
    _notificationOverlay?.remove();
    _notificationOverlay = null;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CamelloPopup(
        isDark: _isDark,
        onDismiss: () {
          entry.remove();
          if (_notificationOverlay == entry) _notificationOverlay = null;
        },
      ),
    );
    _notificationOverlay = entry;
    overlay.insert(entry);
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
    final available = _filteredSkills
        .where((s) => !_skills.contains(s))
        .toList();
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
              borderSide: BorderSide(
                color: _orange.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        if (showList)
          Container(
            constraints: BoxConstraints(
              maxHeight: min(available.length * 48.0, 200),
            ),
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
                          ? Border(
                              bottom: BorderSide(color: _border, width: 0.5),
                            )
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
      return Text(
        skill,
        style: GoogleFonts.poppins(fontSize: 14, color: _txtPri),
      );
    }
    final idx = skill.indexOf(query);
    if (idx == -1) {
      return Text(
        skill,
        style: GoogleFonts.poppins(fontSize: 14, color: _txtSec),
      );
    }
    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(fontSize: 14, color: _txtSec),
        children: [
          if (idx > 0) TextSpan(text: skill.substring(0, idx)),
          TextSpan(
            text: skill.substring(idx, idx + query.length),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _orange,
            ),
          ),
          if (idx + query.length < skill.length)
            TextSpan(text: skill.substring(idx + query.length)),
        ],
      ),
    );
  }

  Future<void> _loadAssignedRequests(String userId) async {
    setState(() => _loadingAssigned = true);
    final statuses = ['ON_THE_WAY', 'IN_PROGRESS'];
    final allRequests = <Map<String, dynamic>>[];

    for (final status in statuses) {
      try {
        final response = await sl<Dio>().get(
          '/service-requests',
          queryParameters: {
            'technicianUserId': userId,
            'status': status,
            'page': 0,
            'limit': 50,
          },
        );
        final data = response.data;
        List<dynamic> raw = [];
        if (data is Map<String, dynamic>) {
          raw = (data['requests'] ?? []) as List<dynamic>;
        } else if (data is List) {
          raw = data;
        }
        allRequests.addAll(raw.whereType<Map<String, dynamic>>());
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _assignedRequests = allRequests;
        _loadingAssigned = false;
      });
      for (final req in allRequests) {
        final id = req['id']?.toString() ?? '';
        if (id.isNotEmpty) sl<WebSocketService>().joinRequestRoom(id);
      }
    }
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

  Future<void> _acceptRequest(String requestId, String technicianId) async {
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
            content: Text('Solicitud aceptada', style: GoogleFonts.poppins()),
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
              _newRequests.removeWhere((r) => r['id']?.toString() == requestId);
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
    _notificationOverlay?.remove();
    _notificationOverlay = null;
    if (_wsInitialized) {
      sl<WebSocketService>().offNewServiceRequest();
      sl<WebSocketService>().offTechnicianStatsUpdated();
      sl<WebSocketService>().offServiceStatusUpdated();
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

        if (!_assignedInitialized) {
          _assignedInitialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadAssignedRequests(user.id);
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
              _buildCamellosActivosTab(user),
              _buildProfileTab(user),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (i) {
              setState(() => _selectedIndex = i);
              if (i == 1) _loadAvailableRequests(user.id);
              if (i == 2) _loadAssignedRequests(user.id);
            },
            type: BottomNavigationBarType.fixed,
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
                label: 'Alrededores',
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ProfilePhotoWidget(
                          photoUrl: user.profilePhotoUrl,
                          name: user.fullName,
                          radius: 22,
                        ),
                        const SizedBox(width: 10),
                        // "Modo Profesional" badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _orange.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified,
                                size: 12,
                                color: _orange,
                              ),
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
                      ],
                    ),
                    // Notification bell with optional pop-up label
                    GestureDetector(
                      onTap: () => _showNotificationsPanel(context, user.id),
                      child: Stack(
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
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        '$_servicesCount',
                        'Servicios',
                        Icons.check_circle_rounded,
                        AppColors.primary,
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

          if (_assignedRequests.isNotEmpty) ...[
            _buildCamellosAceptadosSection(technicianId: user.id),
            const SizedBox(height: 16),
            _buildPosiblesCamellosSection(user),
          ] else ...[
            _buildPosiblesCamellosSection(user),
            const SizedBox(height: 16),
            _buildCamellosAceptadosSection(technicianId: user.id),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPosiblesCamellosSection(User user) {
    return Padding(
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
                  'Posibles Camellos',
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
                      'No hay camellos posibles',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: _txtSec,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recibirás notificaciones cuando haya nuevos camellos disponibles',
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
                  itemBuilder: (context, index) => _buildRequestPreviewCard(
                    _newRequests[index],
                    user.id,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCamellosAceptadosSection({String technicianId = ''}) {
    return Padding(
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
                  'Camellos Aceptados',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _txtPri,
                  ),
                ),
                if (_assignedRequests.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_assignedRequests.length}',
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
            if (_loadingAssigned)
              const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            else if (_assignedRequests.isEmpty)
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
                      'No tienes camellos aceptados',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: _txtSec,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _assignedRequests.length,
                itemBuilder: (context, index) =>
                    _buildAssignedServiceCard(
                      _assignedRequests[index],
                      technicianId,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignedServiceCard(
    Map<String, dynamic> request,
    String technicianId,
  ) {
    final problema = request['problema']?.toString() ?? 'Sin descripción';
    final address = request['addressText']?.toString();
    final skills =
        (request['requestedSkills'] as List?)
            ?.map((s) => s.toString())
            .take(2)
            .join(', ') ??
        '';
    final status = request['status']?.toString() ?? '';
    final isInProgress = status == 'IN_PROGRESS';
    final requestId = request['id']?.toString() ?? '';
    final tenantId =
        request['serviceCity']?.toString() ?? sl<TenantService>().tenantId ?? '';
    final clientLat =
        (request['latitude'] as num?)?.toDouble() ?? 0.0;
    final clientLng =
        (request['longitude'] as num?)?.toDouble() ?? 0.0;
    final startedAtRaw = request['startedAt']?.toString();
    final startedAt =
        startedAtRaw != null ? DateTime.tryParse(startedAtRaw) : null;
    final technicianMarkedComplete =
        request['technicianMarkedComplete'] as bool? ?? false;

    final userId = request['userId']?.toString() ?? '';
    final clientInfo = <String, dynamic>{
      'fullName': userId,
      'phoneNumber': null,
    };

    final statusLabel = isInProgress ? 'En progreso' : 'Asignado';
    final statusColor =
        isInProgress ? AppColors.success : AppColors.primary;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ServiceMapPage(
              requestId: requestId,
              technicianId: technicianId,
              tenantId: tenantId,
              clientLatitude: clientLat,
              clientLongitude: clientLng,
              clientInfo: clientInfo,
              serviceStatus: status,
              startedAt: startedAt,
              technicianMarkedComplete: technicianMarkedComplete,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                if (isInProgress && startedAt != null) ...[
                  const SizedBox(width: 8),
                  _ProviderElapsedTimer(startedAt: startedAt),
                ],
                const Spacer(),
                Icon(Icons.chevron_right, size: 16, color: _txtSec),
              ],
            ),
            const SizedBox(height: 8),
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
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.primary,
                ),
              ),
            ],
            if (address != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 12, color: _txtSec),
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
          ],
        ),
      ),
    );
  }

  Widget _buildRequestPreviewCard(Map<String, dynamic> request, String userId) {
    final problema = request['problema']?.toString() ?? 'Sin descripción';
    final skills =
        (request['requestedSkills'] as List?)
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
                  label: _isDark
                      ? 'Cambiar a modo claro'
                      : 'Cambiar a modo oscuro',
                  showChevron: false,
                  onTap: () => sl<ThemeService>().toggle(),
                ),
                const _ProDivider(),
                _ProMenuItem(
                  icon: Icons.check_circle_outline,
                  label: 'Servicios',
                  onTap: () {
                    setState(() => _selectedIndex = 1);
                    _loadAvailableRequests(user.id);
                  },
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
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._skills.map(
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
                          side: BorderSide(
                            color: _orange.withValues(alpha: 0.35),
                          ),
                          deleteIconColor: _orange,
                          onDeleted: () => _removeSkill(s),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: GestureDetector(
                          onTap: () => _showComingSoon(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add,
                                  size: 12,
                                  color: AppColors.primary.withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Sugerir habilidad',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppColors.primary.withValues(
                                      alpha: 0.5,
                                    ),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
                  icon: Icons.info_outline,
                  label: 'Más información',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MoreInformationPage(),
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
      return const Center(child: CircularProgressIndicator(color: _orange));
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
        final skills =
            (r['requestedSkills'] as List?)
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
                    Icon(Icons.location_on_outlined, size: 13, color: _txtSec),
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

  Widget _buildCamellosActivosTab(User user) {
    if (_loadingAssigned) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_assignedRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.work_outline,
              size: 56,
              color: _txtSec.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 14),
            Text(
              'No tienes camellos activos',
              style: GoogleFonts.poppins(fontSize: 15, color: _txtSec),
            ),
            const SizedBox(height: 8),
            Text(
              'Aquí verás los servicios que hayas aceptado',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _txtSec.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _loadAssignedRequests(user.id),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _assignedRequests.length,
        itemBuilder: (context, index) => _buildAssignedServiceCard(
          _assignedRequests[index],
          user.id,
        ),
      ),
    );
  }


  // ── STAT CARD ────────────────────────────────────────────────────────────────

  BottomNavigationBarItem _navItem(
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    Widget buildColumn(IconData iconData, bool active) => SizedBox(
          height: 52,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(iconData),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? _orange : const Color(0xFF555555),
                  height: 1.2,
                ),
              ),
            ],
          ),
        );

    return BottomNavigationBarItem(
      icon: buildColumn(icon, false),
      activeIcon: buildColumn(activeIcon, true),
      label: label,
    );
  }

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

class _CamelloPopup extends StatefulWidget {
  final bool isDark;
  final VoidCallback onDismiss;

  const _CamelloPopup({required this.isDark, required this.onDismiss});

  @override
  State<_CamelloPopup> createState() => _CamelloPopupState();
}

class _CamelloPopupState extends State<_CamelloPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 3), _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF1C1C1C) : Colors.white;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '¡Camellos\ndisponibles!',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderElapsedTimer extends StatefulWidget {
  final DateTime startedAt;
  const _ProviderElapsedTimer({required this.startedAt});

  @override
  State<_ProviderElapsedTimer> createState() => _ProviderElapsedTimerState();
}

class _ProviderElapsedTimerState extends State<_ProviderElapsedTimer> {
  late int _seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _seconds = DateTime.now().difference(widget.startedAt).inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.timer_outlined, size: 12, color: AppColors.success),
        const SizedBox(width: 3),
        Text(
          _format(_seconds),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

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
      final rs =
          (r['requestedSkills'] as List?)
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
                  final skills =
                      (r['requestedSkills'] as List?)
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
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
    final defaultLabelColor =
        labelColor ?? (isDark ? Colors.white : AppColors.textPrimary);
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
