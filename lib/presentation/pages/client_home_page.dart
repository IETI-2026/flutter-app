import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_bloc.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_state.dart';
import 'package:flutter_app/presentation/bloc/location/location_cubit.dart';
import 'package:flutter_app/presentation/bloc/location/location_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  late final LocationCubit _locationCubit;

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

    final problemaController = TextEditingController();
    final problema = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Describe el problema'),
          content: TextField(
            controller: problemaController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ej: El lavamanos tiene una fuga y gotea constantemente',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(problemaController.text.trim()),
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

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            serverMessage ?? 'No se pudo crear la solicitud de servicio',
          ),
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
            title: const Text(
              'CameYo',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  // TODO: Navigate to notifications
                },
              ),
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  // TODO: Open drawer or menu
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
                        'Servicios Populares',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        children: [
                          _buildServiceCard(
                            'Plomería',
                            Icons.plumbing,
                            AppColors.primary,
                          ),
                          _buildServiceCard(
                            'Electricidad',
                            Icons.electrical_services,
                            AppColors.secondary,
                          ),
                          _buildServiceCard(
                            'Limpieza',
                            Icons.cleaning_services,
                            AppColors.success,
                          ),
                          _buildServiceCard(
                            'Carpintería',
                            Icons.handyman,
                            AppColors.warning,
                          ),
                        ],
                      ),
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
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.grey,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Inicio',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Buscar',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.list_alt),
                label: 'Mis Servicios',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Perfil',
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _onCreateServiceRequest(context, user.id),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add),
            label: const Text('Solicitar Servicio'),
          ),
        );
      },
    );
  }

  Widget _buildServiceCard(String title, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to service detail
        },
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
}
