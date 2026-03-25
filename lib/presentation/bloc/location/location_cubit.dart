import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_app/core/services/tenant_service.dart';
import 'package:flutter_app/data/datasources/geocoding_remote_datasource.dart';
import 'package:flutter_app/presentation/bloc/location/location_state.dart';
import 'package:geolocator/geolocator.dart';

class LocationCubit extends Cubit<LocationState> {
  final GeocodingRemoteDataSource geocodingDataSource;
  final TenantService tenantService;
  final Dio dio;

  LocationCubit({
    required this.geocodingDataSource,
    required this.tenantService,
    required this.dio,
  }) : super(const LocationInitial());

  Future<void> fetchLocation() async {
    emit(const LocationLoading());

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        emit(const LocationError(message: 'Servicio de ubicación desactivado'));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          emit(const LocationError(message: 'Permiso de ubicación denegado'));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
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
      emit(LocationError(message: e.toString()));
    }
  }
}
