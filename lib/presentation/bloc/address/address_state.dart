import 'package:equatable/equatable.dart';
import 'package:flutter_app/domain/entities/address.dart';

abstract class AddressState extends Equatable {
  const AddressState();

  @override
  List<Object?> get props => [];
}

class AddressInitial extends AddressState {
  const AddressInitial();
}

class AddressLoading extends AddressState {
  const AddressLoading();
}

class AddressLoaded extends AddressState {
  final List<Address> addresses;

  const AddressLoaded(this.addresses);

  @override
  List<Object?> get props => [addresses];
}

class AddressOperationSuccess extends AddressState {
  final List<Address> addresses;
  final String message;

  const AddressOperationSuccess({required this.addresses, required this.message});

  @override
  List<Object?> get props => [addresses, message];
}

class AddressError extends AddressState {
  final String message;

  const AddressError(this.message);

  @override
  List<Object?> get props => [message];
}
