import 'package:flutter_app/domain/entities/address.dart';
import 'package:flutter_app/domain/repositories/address_repository.dart';

class CreateAddressParams {
  final String street;
  final String city;
  final String? neighborhood;
  final String? department;
  final String? postalCode;
  final String? label;
  final double? latitude;
  final double? longitude;

  const CreateAddressParams({
    required this.street,
    required this.city,
    this.neighborhood,
    this.department,
    this.postalCode,
    this.label,
    this.latitude,
    this.longitude,
  });
}

class CreateAddressUseCase {
  final AddressRepository repository;

  CreateAddressUseCase(this.repository);

  Future<Address> call(CreateAddressParams params) => repository.createAddress(
    street: params.street,
    city: params.city,
    neighborhood: params.neighborhood,
    department: params.department,
    postalCode: params.postalCode,
    label: params.label,
    latitude: params.latitude,
    longitude: params.longitude,
  );
}
