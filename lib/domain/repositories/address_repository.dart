import 'package:flutter_app/domain/entities/address.dart';

abstract class AddressRepository {
  Future<List<Address>> getAddresses();
  Future<Address> createAddress({
    required String street,
    required String city,
    String? neighborhood,
    String? department,
    String? postalCode,
    String? label,
    double? latitude,
    double? longitude,
  });
  Future<Address> setDefault(String addressId);
  Future<void> deleteAddress(String addressId);
}
