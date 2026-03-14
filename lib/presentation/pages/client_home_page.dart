import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/domain/entities/service_request.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_bloc.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_state.dart';
import 'package:flutter_app/presentation/bloc/location/location_cubit.dart';
import 'package:flutter_app/presentation/bloc/location/location_state.dart';
import 'package:flutter_app/presentation/pages/profile_page.dart';
import 'package:flutter_app/presentation/pages/requested_service_technicians_page.dart';
import 'package:flutter_app/presentation/pages/service_requests_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  late final LocationCubit _locationCubit;
  int _selectedIndex = 0;
  int _misServicesRefreshToken = 0;

  @override
  void initState() {
    super.initState();
    _locationCubit = sl<LocationCubit>()..fetchLocation();
  }

  @override
  void dispose() {
    _locationCubit.close();
    super.dispose();
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

    String problemaInput = '';
    final problemaController = TextEditingController();
    final problema = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Describe el problema'),
          content: TextField(
            controller: problemaController,
            maxLines: 3,
            textCapitalization: TextCapitalization.none,
            inputFormatters: const [_LowerCaseTextFormatter()],
            onChanged: (value) => problemaInput = value.trim(),
            decoration: const InputDecoration(
              hintText:
                  'Ej: El lavamanos tiene una fuga y gotea constantemente',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(problemaInput),
              child: const Text('Crear solicitud'),
            ),
          ],
        );
      },
    );
    problemaController.dispose();

    if (problema == null || problema.isEmpty) {
      return;
    }

    try {
      await sl<Dio>().post(
        '/service-requests',
        data: {
          'userId': userId,
          'problema': problema,
          'latitude': locationState.latitude,
          'longitude': locationState.longitude,
          'addressText': locationState.formattedAddress,
          'serviceCity': locationState.serviceCity,
        },
      );

      if (!context.mounted) return;
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
        if (state is! Authenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = state.user;

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: AppColors.white,
            elevation: 0,
            title: Text(
              _selectedIndex == 3 ? 'Mi Perfil' : 'CameYo',
              style: TextStyle(
                color: _selectedIndex == 3
                    ? AppColors.textPrimary
                    : AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: _selectedIndex == 0
                ? [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {},
                    ),
                  ]
                : null,
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildHomeTab(context, user),
              _buildComingSoonTab(Icons.search, 'Búsqueda'),
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
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.grey,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Inicio',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Buscar',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.list_alt_outlined),
                activeIcon: Icon(Icons.list_alt),
                label: 'Mis Servicios',
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
        );
      },
    );
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 2) {
        _misServicesRefreshToken++;
      }
    });
  }

  Widget _buildComingSoonTab(IconData icon, String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppColors.grey.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            '$label próximamente',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context, user) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '¡Hola, ${user.fullName.split(' ').first}! 👋',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    BlocBuilder<LocationCubit, LocationState>(
                      bloc: _locationCubit,
                      builder: (context, locationState) {
                        if (locationState is LocationLoaded) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 2),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 120,
                                ),
                                child: Text(
                                  locationState.formattedAddress,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        if (locationState is LocationLoading) {
                          return const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '¿Qué servicio necesitas hoy?',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar servicios...',
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
                const Text(
                  'Servicio actual',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<ServiceRequest?>(
                  future: _buildLatestServiceFuture(user.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
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

                    if (snapshot.hasData && snapshot.data != null) {
                      final request = snapshot.data!;
                      return _buildLatestServiceCard(context, request);
                    }

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Aún no hay un servicio visible. Espera a que se cargue la ubicación o intenta recargar.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Tu ubicación actual',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildCurrentLocationMap(),
                const SizedBox(height: 24),
                const Text(
                  'Servicios Recientes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: AppColors.grey.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aún no has solicitado servicios',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<ServiceRequest?> _buildLatestServiceFuture(String userId) async {
    var state = _locationCubit.state;
    if (state is! LocationLoaded) {
      // Wait until location is available so tenant header is already set.
      await _locationCubit.stream.firstWhere((s) => s is LocationLoaded);
      state = _locationCubit.state;
    }

    final tenantId = state is LocationLoaded ? state.serviceCity : null;
    return _fetchLatestServiceRequest(userId, tenantId: tenantId);
  }

  Widget _buildServiceCard(String title, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<ServiceRequest?> _fetchLatestServiceRequest(
    String userId, {
    String? tenantId,
  }) async {
    try {
      final response = await sl<Dio>().get(
        '/service-requests',
        queryParameters: {'userId': userId, 'page': 0, 'limit': 20},
        options: tenantId != null && tenantId.isNotEmpty
            ? Options(headers: {'X-Tenant-ID': tenantId})
            : null,
      );

      final data = response.data;
      List<dynamic> list = [];

      if (data is Map<String, dynamic>) {
        list = (data['requests'] ?? []) as List<dynamic>;
      } else if (data is List) {
        list = data;
      }

      final requests = list
          .whereType<Map<String, dynamic>>()
          .map(
            (json) => ServiceRequest(
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
                  ? DateTime.tryParse(json['createdAt'].toString()) ??
                        DateTime.now()
                  : DateTime.now(),
              updatedAt: json['updatedAt'] != null
                  ? DateTime.tryParse(json['updatedAt'].toString())
                  : null,
            ),
          )
          .toList();

      if (requests.isEmpty) {
        return null;
      }

      requests.sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt;
        final bDate = b.updatedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });

      return requests.first;
    } catch (_) {
      return null;
    }
  }

  Widget _buildLatestServiceCard(BuildContext context, ServiceRequest request) {
    final canOpenTechnicians = request.status.toUpperCase() == 'REQUESTED';
    final status = request.status.toUpperCase();
    final label = switch (status) {
      'REQUESTED' => 'Solicitada',
      'ASSIGNED' => 'Asignada',
      'ON_THE_WAY' => 'En camino',
      'IN_PROGRESS' => 'En progreso',
      'COMPLETED' => 'Completada',
      'CANCELLED' => 'Cancelada',
      'FAILED' => 'Fallida',
      _ => request.status,
    };

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: canOpenTechnicians
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        RequestedServiceTechniciansPage(requestId: request.id),
                  ),
                );
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
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (canOpenTechnicians) ...[
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                request.problema,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (request.addressText != null &&
                  request.addressText!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  request.addressText!,
                  style: const TextStyle(color: AppColors.textSecondary),
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

  Widget _buildCurrentLocationMap() {
    return BlocBuilder<LocationCubit, LocationState>(
      bloc: _locationCubit,
      builder: (context, locationState) {
        if (locationState is! LocationLoaded) {
          return Container(
            height: 210,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final currentPoint = LatLng(
          locationState.latitude,
          locationState.longitude,
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 210,
            child: FlutterMap(
              options: MapOptions(initialCenter: currentPoint, initialZoom: 15),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.cameyo.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentPoint,
                      width: 42,
                      height: 42,
                      child: const Icon(
                        Icons.my_location,
                        color: AppColors.primary,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LowerCaseTextFormatter extends TextInputFormatter {
  const _LowerCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toLowerCase(),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
