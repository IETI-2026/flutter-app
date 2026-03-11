import 'package:dio/dio.dart';
import 'package:flutter_app/core/constants/app_constants.dart';

class GeocodingRemoteDataSource {
  final Dio dio;

  GeocodingRemoteDataSource({required this.dio});

  /// Returns the formatted address for given coordinates.
  Future<String> reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    final response = await dio.post(
      '${AppConstants.baseUrl}/geocoding/reverse',
      data: {'lat': lat, 'lng': lng},
      options: Options(headers: {'X-Tenant-ID': 'public'}),
    );
    return response.data['formattedAddress'] as String;
  }

  /// Returns the tenant for given coordinates and stores it.
  Future<String> getTenant({required double lat, required double lng}) async {
    final response = await dio.post(
      '${AppConstants.baseUrl}/geocoding/tenant',
      data: {'lat': lat, 'lng': lng},
      options: Options(headers: {'X-Tenant-ID': 'public'}),
    );
    return response.data['tenant'] as String;
  }
}
