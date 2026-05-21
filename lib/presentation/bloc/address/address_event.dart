import 'package:equatable/equatable.dart';
import 'package:flutter_app/domain/usecases/create_address_usecase.dart';

abstract class AddressEvent extends Equatable {
  const AddressEvent();

  @override
  List<Object?> get props => [];
}

class LoadAddressesEvent extends AddressEvent {
  const LoadAddressesEvent();
}

class CreateAddressEvent extends AddressEvent {
  final CreateAddressParams params;

  const CreateAddressEvent(this.params);

  @override
  List<Object?> get props => [params];
}

class SetDefaultAddressEvent extends AddressEvent {
  final String addressId;

  const SetDefaultAddressEvent(this.addressId);

  @override
  List<Object?> get props => [addressId];
}

class DeleteAddressEvent extends AddressEvent {
  final String addressId;

  const DeleteAddressEvent(this.addressId);

  @override
  List<Object?> get props => [addressId];
}
