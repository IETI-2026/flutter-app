import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/utils/logger.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/core/services/theme_service.dart';
import 'package:flutter_app/core/services/websocket_service.dart';
import 'package:flutter_app/data/datasources/auth_local_datasource.dart';
import 'package:flutter_app/domain/entities/service_request.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_bloc.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_state.dart';
import 'package:flutter_app/presentation/bloc/location/location_cubit.dart';
import 'package:flutter_app/presentation/bloc/location/location_state.dart';
import 'package:flutter_app/presentation/pages/profile_page.dart';
import 'package:flutter_app/presentation/pages/provider_search_page.dart';
import 'package:flutter_app/presentation/pages/rate_service_page.dart';
import 'package:flutter_app/presentation/pages/requested_service_technicians_page.dart';
import 'package:flutter_app/presentation/pages/service_map_page.dart';
import 'package:flutter_app/presentation/pages/service_requests_page.dart';
import 'package:flutter_app/presentation/pages/address_management_page.dart';
import 'package:flutter_app/presentation/widgets/address_selector_widget.dart';
import 'package:flutter_app/presentation/widgets/profile_photo_widget.dart';
import 'package:flutter_app/presentation/widgets/service_summary_modal.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  late final LocationCubit _locationCubit;
  int _selectedIndex = 0;
  int _misServicesRefreshToken = 0;
  List<ServiceRequest>? _activeServices;
  bool _activeServicesLoading = false;
  String? _activeServicesUserId;
  List<ServiceRequest>? _unratedServices;
  bool _unratedServicesLoading = false;
  bool _isDark = false;
  bool _wsInitialized = false;
  Timer? _locationTimer;
  String? _activeRequestId;
  String? _lastKnownServiceCity;
  final TextEditingController _searchController = TextEditingController();

  Color get _bg =>
      _isDark ? const Color(0xFF0F0F0F) : AppColors.backgroundLight;
  Color get _card => _isDark ? const Color(0xFF1C1C1C) : AppColors.white;
  Color get _cardAlt =>
      _isDark ? const Color(0xFF252525) : AppColors.surfaceSoft;
  Color get _txtPri => _isDark ? Colors.white : AppColors.textPrimary;
  Color get _txtSec =>
      _isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;

  void _onThemeChanged() {
    if (mounted) setState(() => _isDark = sl<ThemeService>().isDark);
  }

  @override
  void initState() {
    super.initState();
    _locationCubit = sl<LocationCubit>();
    // Only start geolocation if not already fetching (may have been pre-warmed
    // by the splash screen while the user was authenticated).
    _locationCubit.fetchLocationIfNeeded();
    _isDark = sl<ThemeService>().isDark;
    sl<ThemeService>().addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _searchController.dispose();
    sl<WebSocketService>().offLocationUpdated();
    sl<WebSocketService>().offServiceStatusUpdated();
    sl<ThemeService>().removeListener(_onThemeChanged);
    // LocationCubit is a singleton — do not close it here.
    super.dispose();
  }

  Future<void> _initWebSocket() async {
    if (_wsInitialized) return;
    _wsInitialized = true;
    final token = await sl<AuthLocalDataSource>().getAccessToken();
    sl<WebSocketService>().connect(token: token);
  }

  void _startLocationTracking(
    String userId,
    String requestId,
    String tenantId,
  ) {
    if (_activeRequestId == requestId) return;
    _activeRequestId = requestId;
    _locationTimer?.cancel();

    sl<WebSocketService>().joinRequestRoom(requestId);

    sl<WebSocketService>().onServiceStatusUpdated((data) {
      final newStatus = data['status']?.toString() ?? '';
      if (newStatus == 'COMPLETED' && mounted) {
        _refreshActiveServices(userId);
      }
    });

    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
        await sl<Dio>().patch(
          '/service-requests/$requestId/update-location',
          data: {
            'latitude': pos.latitude,
            'longitude': pos.longitude,
          },
          options: Options(headers: {'X-Tenant-ID': tenantId}),
        );
      } catch (_) {}
    });
  }

  Future<void> _onCreateServiceRequest(
    BuildContext context,
    String userId,
  ) async {
    final locationState = _locationCubit.state;

    if (locationState is! LocationLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aun estamos obteniendo tu ubicacion. Intenta de nuevo en unos segundos.',
          ),
        ),
      );
      return;
    }

    final problema = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ServiceRequestSheet(),
    );

    if (problema == null || problema.isEmpty) return;

    try {
      await sl<Dio>().post(
        '/service-requests',
        data: {
          'problema': problema,
          'latitude': locationState.latitude,
          'longitude': locationState.longitude,
          'addressText': locationState.formattedAddress,
          'serviceCity': locationState.serviceCity,
        },
      );

      if (!context.mounted) return;
      _refreshActiveServices(userId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud de servicio creada con exito')),
      );
    } on DioException catch (e) {
      final serverMessage = e.response?.data is Map<String, dynamic>
          ? e.response?.data['message']?.toString()
          : null;

      if (e.response?.statusCode == 401) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              serverMessage ??
                  'No autorizado para crear solicitudes con la sesión actual.',
            ),
          ),
        );
        return;
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            serverMessage ?? 'No se pudo crear la solicitud de servicio',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocurrió un error inesperado. Intenta de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthLoading || state is AuthInitial) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is! Authenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            Navigator.pushNamedAndRemoveUntil(context, '/auth-role', (_) => false);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = state.user;

        if (!_wsInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _initWebSocket();
          });
        }

        return BlocListener<LocationCubit, LocationState>(
          bloc: _locationCubit,
          listenWhen: (_, curr) => curr is LocationLoaded,
          listener: (context, locationState) {
            if (locationState is LocationLoaded) {
              if (_lastKnownServiceCity != null &&
                  _lastKnownServiceCity != locationState.serviceCity) {
                _refreshActiveServices(user.id);
                _loadUnratedServices(user.id, forceReload: true);
                setState(() => _misServicesRefreshToken++);
              }
              _lastKnownServiceCity = locationState.serviceCity;
            }
          },
          child: Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _card,
            elevation: 0,
            title: Text(
              _selectedIndex == 2 ? 'Mi Perfil' : 'CameYo',
              style: TextStyle(
                color: _selectedIndex == 2 ? _txtPri : AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: _selectedIndex == 0
                ? [
                    IconButton(
                      icon: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: _txtPri,
                      ),
                      tooltip: 'Pagos',
                      onPressed: () {
                        Navigator.pushNamed(context, '/client-payments');
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.notifications_outlined,
                        color: _txtPri,
                      ),
                      onPressed: () {},
                    ),
                  ]
                : null,
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildHomeTab(context, user),
              BlocBuilder<LocationCubit, LocationState>(
                bloc: _locationCubit,
                builder: (context, locationState) {
                  if (locationState is! LocationLoaded) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  return ServiceRequestsPage(
                    userId: user.id,
                    embedded: true,
                    refreshToken: _misServicesRefreshToken,
                    tenantId: locationState.serviceCity,
                  );
                },
              ),
              ProfilePage(user: user),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onTabSelected,
            type: BottomNavigationBarType.fixed,
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
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
            ],
          ),
          floatingActionButton: _selectedIndex == 0
              ? FloatingActionButton.extended(
                  onPressed: () async =>
                      _onCreateServiceRequest(context, user.id),
                  backgroundColor: AppColors.primary,
                  icon: const Icon(Icons.add),
                  label: const Text('Solicitar Servicio'),
                )
              : null,
        ),
        );
      },
    );
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) {
        _misServicesRefreshToken++;
      }
    });
  }

  Widget _buildHomeTab(BuildContext context, user) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        _refreshActiveServices(user.id);
        await _loadUnratedServices(user.id, forceReload: true);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfilePhotoWidget(
                  photoUrl: user.profilePhotoUrl,
                  name: user.fullName,
                  radius: 24,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '¡Hola, ${user.fullName.split(' ').first}!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _txtPri,
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: AddressSelectorWidget(
                        locationCubit: _locationCubit,
                        isDark: _isDark,
                        onNavigateToAddressManagement: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddressManagementPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '¿Qué camellos necesitas hoy?',
                  style: TextStyle(fontSize: 14, color: _txtSec),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: _cardAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (query) {
                      if (query.trim().isEmpty) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProviderSearchPage(initialQuery: query.trim()),
                        ),
                      );
                      _searchController.clear();
                    },
                    decoration: const InputDecoration(
                      hintText: 'Buscar camellos...',
                      border: InputBorder.none,
                      icon: Icon(Icons.search, color: AppColors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Camellos activos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _txtPri,
                  ),
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    if (_activeServicesUserId != user.id) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _loadActiveServices(user.id);
                      });
                    }

                    if (_activeServicesLoading || _activeServices == null) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: SizedBox(
                            height: 24,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      );
                    }

                    final requests = _activeServices!;

                    if (requests.isEmpty) {
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No tienes camellos activos en este momento.',
                            style: TextStyle(color: _txtSec),
                          ),
                        ),
                      );
                    }

                    return SizedBox(
                      height: 200,
                      child: ListView.separated(
                        itemCount: requests.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _buildLatestServiceCard(
                              context,
                              requests[index],
                              user.id,
                            ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Pendientes de calificar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _txtPri,
                  ),
                ),
                const SizedBox(height: 12),
                _buildUnratedServicesSection(context, user.id),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Future<void> _loadActiveServices(String userId) async {
    if (_activeServicesLoading && _activeServicesUserId == userId) return;
    setState(() {
      _activeServicesUserId = userId;
      _activeServicesLoading = true;
    });

    var locState = _locationCubit.state;
    if (locState is! LocationLoaded) {
      await _locationCubit.stream.firstWhere((s) => s is LocationLoaded);
      locState = _locationCubit.state;
    }
    final tenantId = locState is LocationLoaded ? locState.serviceCity : null;

    final requests = await _fetchRequestedServices(userId, tenantId: tenantId);

    if (!mounted) return;

    // Join WebSocket room for every active request so we receive status events.
    for (final req in requests) {
      sl<WebSocketService>().joinRequestRoom(req.id);
    }

    // Single handler: update status in-place when backend emits events.
    sl<WebSocketService>().offServiceStatusUpdated();
    sl<WebSocketService>().onServiceStatusUpdated((data) {
      if (!mounted) return;
      final requestId = data['requestId']?.toString() ?? '';
      final newStatus = data['status']?.toString() ?? '';
      if (requestId.isEmpty || newStatus.isEmpty) return;

      if (newStatus == 'COMPLETED') {
        _showServiceSummary(requestId, tenantId ?? '');
      }

      setState(() {
        final list = _activeServices;
        if (list == null) return;
        if (newStatus == 'COMPLETED' || newStatus == 'CANCELLED') {
          list.removeWhere((r) => r.id == requestId);
        } else {
          final idx = list.indexWhere((r) => r.id == requestId);
          if (idx >= 0) {
            list[idx] = list[idx].copyWith(status: newStatus);
          } else {
            _loadActiveServices(userId);
          }
        }
      });
    });

    // Location tracking for the first ON_THE_WAY / IN_PROGRESS request.
    if (tenantId != null) {
      final active = requests.where(
        (r) => r.status == 'ON_THE_WAY' || r.status == 'IN_PROGRESS',
      );
      if (active.isNotEmpty) {
        _startLocationTracking(userId, active.first.id, tenantId);
      }
    }

    setState(() {
      _activeServices = requests;
      _activeServicesLoading = false;
    });
  }

  void _refreshActiveServices(String userId) {
    setState(() {
      _activeServicesUserId = null;
      _activeServices = null;
    });
    _loadActiveServices(userId);
  }

  Future<void> _loadUnratedServices(
    String userId, {
    bool forceReload = false,
  }) async {
    if (!forceReload && _unratedServicesLoading) return;
    if (!forceReload && _unratedServices != null) return;

    setState(() => _unratedServicesLoading = true);

    var locState = _locationCubit.state;
    if (locState is! LocationLoaded) {
      try {
        await _locationCubit.stream.firstWhere(
          (s) => s is LocationLoaded || s is LocationError,
        );
        locState = _locationCubit.state;
      } catch (_) {}
    }

    try {
      final response = await sl<Dio>().get(
        '/service-requests',
        queryParameters: {
          'userId': userId,
          'status': 'COMPLETED',
          'isRated': false,
          'page': 0,
          'limit': 50,
        },
      );
      final data = response.data;
      List<dynamic> list = [];
      if (data is Map<String, dynamic>) {
        list = (data['requests'] ?? []) as List<dynamic>;
      } else if (data is List) {
        list = data;
      }
      if (!mounted) return;
      setState(() {
        _unratedServices = list
            .whereType<Map<String, dynamic>>()
            .map(_parseServiceRequest)
            .toList();
        _unratedServicesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _unratedServicesLoading = false);
    }
  }

  Widget _buildUnratedServicesSection(BuildContext context, String userId) {
    if (_unratedServices == null || _unratedServicesLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadUnratedServices(userId);
      });
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            height: 24,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      );
    }

    final services = _unratedServices!;

    if (services.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No tienes servicios pendientes de calificar.',
            style: TextStyle(color: _txtSec),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: services.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final service = services[index];
        return _buildUnratedServiceCard(context, service, userId);
      },
    );
  }

  Widget _buildUnratedServiceCard(
    BuildContext context,
    ServiceRequest service,
    String userId,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final tenantId = service.serviceCity ?? '';
          final rated = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => RateServicePage(
                serviceRequestId: service.id,
                technicianName: service.technicianName ?? 'Técnico',
                serviceName: service.categoryName ?? service.problema,
                tenantId: tenantId,
              ),
            ),
          );
          if (rated == true) {
            setState(() {
              _unratedServices?.removeWhere((s) => s.id == service.id);
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.star_outline_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.categoryName ?? service.problema,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _txtPri,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (service.technicianName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Técnico: ${service.technicianName}',
                        style: TextStyle(fontSize: 13, color: _txtSec),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: _txtSec),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showServiceSummary(
    String requestId,
    String tenantId,
  ) async {
    try {
      final response = await sl<Dio>().get(
        '/service-requests/$requestId',
        options: tenantId.isNotEmpty
            ? Options(headers: {'X-Tenant-ID': tenantId})
            : null,
      );
      if (!mounted) return;
      final data = response.data as Map<String, dynamic>;
      final serviceRequest = _parseServiceRequest(data);
      await ServiceSummaryModal.show(
        context,
        serviceRequest: serviceRequest,
        tenantId: tenantId,
      );
    } catch (e) {
      AppLogger.error('Error fetching service summary: $e');
    }
  }

  ServiceRequest _parseServiceRequest(Map<String, dynamic> json) {
    return ServiceRequest(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      assignedTechnicianId: json['assignedTechnicianId']?.toString(),
      problema: json['problema']?.toString() ?? '',
      status: json['status']?.toString() ?? 'UNKNOWN',
      urgency: json['urgency']?.toString(),
      requestedSkills: (json['requestedSkills'] is List)
          ? (json['requestedSkills'] as List)
                .map((skill) => skill.toString())
                .toList()
          : const [],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      addressText: json['addressText']?.toString(),
      serviceCity: json['serviceCity']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString())
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      clientMarkedComplete: json['clientMarkedComplete'] as bool? ?? false,
      technicianMarkedComplete:
          json['technicianMarkedComplete'] as bool? ?? false,
      displacementDistanceKm:
          (json['displacementDistanceKm'] as num?)?.toDouble(),
      finalPrice: (json['finalPrice'] != null)
          ? double.tryParse(json['finalPrice'].toString())
          : null,
      technicianName: json['technicianName']?.toString(),
      technicianPhotoUrl: json['technicianPhotoUrl']?.toString(),
      technicianRating: (json['technicianRating'] as num?)?.toDouble(),
      categoryName: json['categoryName']?.toString(),
    );
  }

  Future<List<ServiceRequest>> _fetchRequestedServices(
    String userId, {
    String? tenantId,
  }) async {
    final statuses = ['REQUESTED', 'ASSIGNED', 'ON_THE_WAY', 'IN_PROGRESS'];
    final allRequests = <ServiceRequest>[];
    final options = tenantId != null && tenantId.isNotEmpty
        ? Options(headers: {'X-Tenant-ID': tenantId})
        : null;

    for (final status in statuses) {
      try {
        final response = await sl<Dio>().get(
          '/service-requests',
          queryParameters: {
            'userId': userId,
            'status': status,
            'page': 0,
            'limit': 50,
          },
          options: options,
        );

        final data = response.data;
        List<dynamic> list = [];
        if (data is Map<String, dynamic>) {
          list = (data['requests'] ?? []) as List<dynamic>;
        } else if (data is List) {
          list = data;
        }

        allRequests.addAll(
          list.whereType<Map<String, dynamic>>().map(_parseServiceRequest),
        );
      } catch (_) {}
    }

    allRequests.sort((a, b) {
      final aDate = a.updatedAt ?? a.createdAt;
      final bDate = b.updatedAt ?? b.createdAt;
      return bDate.compareTo(aDate);
    });

    return allRequests;
  }

  Widget _buildLatestServiceCard(
    BuildContext context,
    ServiceRequest request,
    String userId,
  ) {
    final status = request.status.toUpperCase();
    final isRequested = status == 'REQUESTED';
    final isOnTheWay = status == 'ON_THE_WAY';
    final isInProgress = status == 'IN_PROGRESS';
    final isActive = isOnTheWay || isInProgress;

    final label = switch (status) {
      'REQUESTED' => 'Solicitada',
      'ON_THE_WAY' => 'En camino',
      'IN_PROGRESS' => 'En progreso',
      'COMPLETED' => 'Completada',
      'CANCELLED' => 'Cancelada',
      'FAILED' => 'Fallida',
      _ => request.status,
    };

    final labelColor = isInProgress ? AppColors.success : AppColors.primary;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isRequested
            ? () {
                Navigator.of(context)
                    .push<bool>(
                      MaterialPageRoute(
                        builder: (_) => RequestedServiceTechniciansPage(
                          requestId: request.id,
                          clientUserId: userId,
                          tenantId: request.serviceCity ?? '',
                          requestLatitude: request.latitude,
                          requestLongitude: request.longitude,
                        ),
                      ),
                    )
                    .then((chosen) {
                  if (chosen == true) _refreshActiveServices(userId);
                });
              }
            : isActive
            ? () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => ServiceMapPage(
                          requestId: request.id,
                          technicianId: request.assignedTechnicianId ?? '',
                          tenantId: request.serviceCity ?? '',
                          clientLatitude: request.latitude ?? 0,
                          clientLongitude: request.longitude ?? 0,
                          clientInfo: const {},
                          serviceStatus: request.status,
                          startedAt: request.startedAt,
                          technicianMarkedComplete:
                              request.technicianMarkedComplete,
                          clientMarkedComplete: request.clientMarkedComplete,
                          isClientView: true,
                          clientUserId: userId,
                          technicianName: request.technicianName,
                          technicianRating: request.technicianRating,
                          technicianPhotoUrl: request.technicianPhotoUrl,
                        ),
                      ),
                    )
                    .then((_) => _loadActiveServices(userId));
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: labelColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: labelColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isInProgress && request.startedAt != null) ...[
                    const SizedBox(width: 8),
                    _ElapsedTimer(startedAt: request.startedAt!),
                  ],
                  if (isRequested || isActive) ...[
                    const Spacer(),
                    Icon(Icons.chevron_right, color: _txtSec),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                request.problema,
                style: TextStyle(fontWeight: FontWeight.w600, color: _txtPri),
              ),
              if (request.addressText != null &&
                  request.addressText!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  request.addressText!,
                  style: TextStyle(color: _txtSec),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

}

class _ElapsedTimer extends StatefulWidget {
  final DateTime startedAt;
  const _ElapsedTimer({required this.startedAt});

  @override
  State<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<_ElapsedTimer> {
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
        Icon(Icons.timer_outlined, size: 14, color: AppColors.success),
        const SizedBox(width: 3),
        Text(
          _format(_seconds),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _ServiceRequestSheet extends StatefulWidget {
  const _ServiceRequestSheet();

  @override
  State<_ServiceRequestSheet> createState() => _ServiceRequestSheetState();
}

class _ServiceRequestSheetState extends State<_ServiceRequestSheet> {
  static const _method = MethodChannel('com.cameyo.app/speech');
  static const _events = EventChannel('com.cameyo.app/speech_events');

  final _controller = TextEditingController();
  bool _isListening = false;
  StreamSubscription<dynamic>? _sub;

  Future<void> _startVoiceInput() async {
    if (_isListening) {
      await _method.invokeMethod('stop');
      return;
    }

    FocusScope.of(context).unfocus();

    _sub?.cancel();
    _sub = _events.receiveBroadcastStream().listen((event) {
      if (!mounted) return;
      final type = event['type'] as String;
      final value = event['value'];
      switch (type) {
        case 'partial':
          setState(() {
            _controller.text = (value as String).toLowerCase();
            _controller.selection = TextSelection.collapsed(
              offset: _controller.text.length,
            );
          });
        case 'result':
          setState(() {
            _isListening = false;
            _controller.text = (value as String).toLowerCase();
            _controller.selection = TextSelection.collapsed(
              offset: _controller.text.length,
            );
          });
        case 'error':
          setState(() => _isListening = false);
        case 'status':
          if (value == 'listening') setState(() => _isListening = true);
          if (value == 'processing') setState(() => _isListening = false);
      }
    });

    try {
      await _method.invokeMethod('start');
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _isListening = false);
      if (e.code == 'PERMISSION_DENIED') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se necesita permiso de micrófono para dictar.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isListening = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _method.invokeMethod('cancel');
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Describe el problema',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            autocorrect: true,
            enableSuggestions: true,
            autofocus: false,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText:
                  'ej: el lavamanos tiene una fuga y gotea constantemente',
              hintStyle: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: IconButton(
                tooltip: _isListening ? 'Detener dictado' : 'Dictar por voz',
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? AppColors.primary : AppColors.grey,
                ),
                onPressed: _isListening ? null : _startVoiceInput,
              ),
            ),
          ),
          if (_isListening)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 8, color: Colors.red.shade400),
                  const SizedBox(width: 6),
                  Text(
                    'Escuchando...',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade400),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final text = _controller.text.trim().toLowerCase();
                if (text.isNotEmpty) Navigator.of(context).pop(text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Crear solicitud',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
