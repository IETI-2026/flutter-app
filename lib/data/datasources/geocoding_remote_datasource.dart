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

  /// Returns structured address components from coordinates for autocomplete.
  Future<Map<String, String?>> reverseGeocodeComponents({
    required double lat,
    required double lng,
  }) async {
    final response = await dio.post(
      '${AppConstants.baseUrl}/geocoding/reverse',
      data: {'lat': lat, 'lng': lng},
      options: Options(headers: {'X-Tenant-ID': 'public'}),
    );

    final data = response.data as Map<String, dynamic>;
    final components =
        (data['components'] as List<dynamic>?) ?? <dynamic>[];

    String? findComponent(List<String> types) {
      for (final comp in components) {
        final compMap = comp as Map<String, dynamic>;
        final compTypes = (compMap['types'] as List<dynamic>)
            .map((t) => t.toString())
            .toList();
        if (types.any((t) => compTypes.contains(t))) {
          return compMap['long_name'] as String?;
        }
      }
      return null;
    }

    return {
      'street': findComponent(['route']),
      'city': findComponent([
        'locality',
        'administrative_area_level_2',
      ]),
      'neighborhood': findComponent(['neighborhood', 'sublocality']),
      'department': findComponent(['administrative_area_level_1']),
    };
  }
}
