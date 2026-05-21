import 'package:dio/dio.dart';
import 'package:flutter_app/data/models/address_model.dart';

class AddressRemoteDataSource {
  final Dio dio;

  AddressRemoteDataSource({required this.dio});

  Future<List<AddressModel>> getAddresses() async {
    final response = await dio.get('/addresses');
    final list = response.data as List<dynamic>;
    return list
        .map((e) => AddressModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AddressModel> createAddress({
    required String street,
    required String city,
    String? neighborhood,
    String? department,
    String? postalCode,
    String? label,
    double? latitude,
    double? longitude,
  }) async {
    final body = <String, dynamic>{
      'street': street,
      'city': city,
    };
    if (neighborhood != null) body['neighborhood'] = neighborhood;
    if (department != null) body['department'] = department;
    if (postalCode != null) body['postalCode'] = postalCode;
    if (label != null) body['label'] = label;
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;

    final response = await dio.post('/addresses', data: body);
    return AddressModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AddressModel> setDefault(String addressId) async {
    final response = await dio.patch('/addresses/$addressId/default');
    return AddressModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteAddress(String addressId) async {
    await dio.delete('/addresses/$addressId');
  }
}
