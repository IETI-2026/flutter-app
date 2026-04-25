import 'package:flutter_app/data/datasources/address_remote_datasource.dart';
import 'package:flutter_app/domain/entities/address.dart';
import 'package:flutter_app/domain/repositories/address_repository.dart';

class AddressRepositoryImpl implements AddressRepository {
  final AddressRemoteDataSource remoteDataSource;

  AddressRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Address>> getAddresses() => remoteDataSource.getAddresses();

  @override
  Future<Address> createAddress({
    required String street,
    required String city,
    String? neighborhood,
    String? department,
    String? postalCode,
    String? label,
    double? latitude,
    double? longitude,
  }) =>
      remoteDataSource.createAddress(
        street: street,
        city: city,
        neighborhood: neighborhood,
        department: department,
        postalCode: postalCode,
        label: label,
        latitude: latitude,
        longitude: longitude,
      );

  @override
  Future<Address> setDefault(String addressId) =>
      remoteDataSource.setDefault(addressId);

  @override
  Future<void> deleteAddress(String addressId) =>
      remoteDataSource.deleteAddress(addressId);
}
