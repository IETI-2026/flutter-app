import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/domain/entities/address.dart';
import 'package:flutter_app/presentation/bloc/address/address_bloc.dart';
import 'package:flutter_app/presentation/bloc/address/address_event.dart';
import 'package:flutter_app/presentation/bloc/address/address_state.dart';
import 'package:flutter_app/presentation/bloc/location/location_cubit.dart';
import 'package:flutter_app/presentation/bloc/location/location_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddressSelectorWidget extends StatelessWidget {
  final LocationCubit locationCubit;
  final bool isDark;
  final VoidCallback onNavigateToAddressManagement;

  const AddressSelectorWidget({
    super.key,
    required this.locationCubit,
    required this.isDark,
    required this.onNavigateToAddressManagement,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocationCubit, LocationState>(
      bloc: locationCubit,
      builder: (context, locationState) {
        final txtSec =
            isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;

        String addressText;
        bool isLoading = false;

        if (locationState is LocationLoaded) {
          addressText = locationState.formattedAddress;
        } else if (locationState is LocationOptimistic) {
          addressText = locationState.displayLabel;
        } else if (locationState is LocationLoading) {
          addressText = 'Obteniendo ubicación...';
          isLoading = true;
        } else {
          addressText = 'Sin ubicación';
        }

        return GestureDetector(
          onTap: isLoading
              ? null
              : () => _showAddressSheet(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  addressText,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(fontSize: 12, color: txtSec),
                ),
              ),
              if (!isLoading) Icon(Icons.expand_more, size: 16, color: txtSec),
            ],
          ),
        );
      },
    );
  }

  void _showAddressSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (_) => sl<AddressBloc>()..add(const LoadAddressesEvent()),
        child: _AddressPickerSheet(
          locationCubit: locationCubit,
          isDark: isDark,
          onNavigateToAddressManagement: onNavigateToAddressManagement,
        ),
      ),
    );
  }
}

class _AddressPickerSheet extends StatelessWidget {
  final LocationCubit locationCubit;
  final bool isDark;
  final VoidCallback onNavigateToAddressManagement;

  const _AddressPickerSheet({
    required this.locationCubit,
    required this.isDark,
    required this.onNavigateToAddressManagement,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1C1C1C) : Colors.white;
    final txtPri = isDark ? Colors.white : AppColors.textPrimary;
    final txtSec =
        isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Selecciona una dirección',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: txtPri,
            ),
          ),
          const SizedBox(height: 16),
          BlocConsumer<AddressBloc, AddressState>(
            listener: (context, state) {
              if (state is AddressError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message)),
                );
              }
            },
            builder: (context, state) {
              if (state is AddressLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                );
              }

              final addresses = state is AddressLoaded
                  ? state.addresses
                  : state is AddressOperationSuccess
                      ? state.addresses
                      : <Address>[];

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...addresses.map(
                    (addr) => _AddressListTile(
                      address: addr,
                      isDark: isDark,
                      txtPri: txtPri,
                      txtSec: txtSec,
                      onTap: () => _selectAddress(context, addr),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      onNavigateToAddressManagement();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Text(
                            '+ Nueva dirección',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _selectAddress(BuildContext context, Address address) {
    if (!address.hasCoordinates) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Esta dirección no tiene coordenadas. Edítala y selecciona la ubicación en el mapa.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop();

    locationCubit.fetchLocationFromAddress(
      latitude: address.latitude!,
      longitude: address.longitude!,
      optimisticLabel: address.displayName,
    );
  }
}

class _AddressListTile extends StatelessWidget {
  final Address address;
  final bool isDark;
  final Color txtPri;
  final Color txtSec;
  final VoidCallback onTap;

  const _AddressListTile({
    required this.address,
    required this.isDark,
    required this.txtPri,
    required this.txtSec,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                address.isDefault ? Icons.home : Icons.location_on_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (address.label != null && address.label!.isNotEmpty)
                    Text(
                      address.label!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: txtPri,
                        fontSize: 14,
                      ),
                    ),
                  Text(
                    address.displayName,
                    style: TextStyle(color: txtSec, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!address.hasCoordinates)
                    Text(
                      'Sin coordenadas',
                      style: TextStyle(
                        color: Colors.orange.shade400,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            if (address.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Principal',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
