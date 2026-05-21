import 'package:flutter_app/domain/entities/address.dart';
import 'package:flutter_app/domain/repositories/address_repository.dart';

class SetDefaultAddressUseCase {
  final AddressRepository repository;

  SetDefaultAddressUseCase(this.repository);

  Future<Address> call(String addressId) => repository.setDefault(addressId);
}
