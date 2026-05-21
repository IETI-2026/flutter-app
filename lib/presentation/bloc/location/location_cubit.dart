import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_app/core/services/tenant_service.dart';
import 'package:flutter_app/core/utils/logger.dart';
import 'package:flutter_app/data/datasources/geocoding_remote_datasource.dart';
import 'package:flutter_app/presentation/bloc/location/location_state.dart';
import 'package:geolocator/geolocator.dart';

class LocationCubit extends Cubit<LocationState> {
  final GeocodingRemoteDataSource geocodingDataSource;
  final TenantService tenantService;
  final Dio dio;

  int _version = 0;

  LocationCubit({
    required this.geocodingDataSource,
    required this.tenantService,
    required this.dio,
  }) : super(const LocationInitial());

  Future<void> fetchLocation() async {
    final myVersion = ++_version;
    emit(const LocationLoading());

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.warning('Location service disabled');
        if (myVersion != _version) return;
        emit(const LocationError(message: 'Servicio de ubicación desactivado'));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (myVersion != _version) return;
          emit(const LocationError(message: 'Permiso de ubicación denegado'));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (myVersion != _version) return;
        emit(
          const LocationError(
            message: 'Permiso de ubicación denegado permanentemente',
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final tenant = await geocodingDataSource.getTenant(
        lat: position.latitude,
        lng: position.longitude,
      );
      tenantService.setTenant(tenant);

      final address = await geocodingDataSource.reverseGeocode(
        lat: position.latitude,
        lng: position.longitude,
      );

      AppLogger.event('location_resolved', {'city': tenant});

      if (myVersion != _version) return;
      emit(
        LocationLoaded(
          formattedAddress: address,
          latitude: position.latitude,
          longitude: position.longitude,
          serviceCity: tenant,
        ),
      );

      try {
        await dio.patch(
          '/users/me/location',
          data: {
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
        );
      } catch (_) {}
    } catch (e) {
      if (myVersion != _version) return;
      AppLogger.error('Location fetch failed', e);
      emit(LocationError(message: e.toString()));
    }
  }

  void fetchLocationIfNeeded() {
    if (state is LocationInitial) {
      fetchLocation();
    }
  }

  void reset() {
    if (!isClosed) {
      emit(const LocationInitial());
    }
  }

  Future<void> fetchLocationFromAddress({
    required double latitude,
    required double longitude,
    String? optimisticLabel,
  }) async {
    final myVersion = ++_version;
    if (optimisticLabel != null) {
      emit(LocationOptimistic(
        displayLabel: optimisticLabel,
        latitude: latitude,
        longitude: longitude,
      ));
    } else {
      emit(const LocationLoading());
    }
    try {
      final tenant = await geocodingDataSource.getTenant(
        lat: latitude,
        lng: longitude,
      );
      tenantService.setTenant(tenant);

      final address = await geocodingDataSource.reverseGeocode(
        lat: latitude,
        lng: longitude,
      );

      AppLogger.event('address_selected', {'city': tenant});

      if (myVersion != _version) return;
      emit(
        LocationLoaded(
          formattedAddress: address,
          latitude: latitude,
          longitude: longitude,
          serviceCity: tenant,
        ),
      );
    } catch (e) {
      if (myVersion != _version) return;
      AppLogger.error('Failed to resolve location from address', e);
      emit(LocationError(message: e.toString()));
    }
  }
}
