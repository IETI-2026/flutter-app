import 'package:flutter_app/domain/repositories/address_repository.dart';

class DeleteAddressUseCase {
  final AddressRepository repository;

  DeleteAddressUseCase(this.repository);

  Future<void> call(String addressId) => repository.deleteAddress(addressId);
}
