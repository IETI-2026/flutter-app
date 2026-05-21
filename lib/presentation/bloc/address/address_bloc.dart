import 'package:flutter_app/core/utils/logger.dart';
import 'package:flutter_app/domain/usecases/create_address_usecase.dart';
import 'package:flutter_app/domain/usecases/delete_address_usecase.dart';
import 'package:flutter_app/domain/usecases/get_addresses_usecase.dart';
import 'package:flutter_app/domain/usecases/set_default_address_usecase.dart';
import 'package:flutter_app/presentation/bloc/address/address_event.dart';
import 'package:flutter_app/presentation/bloc/address/address_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddressBloc extends Bloc<AddressEvent, AddressState> {
  final GetAddressesUseCase getAddresses;
  final CreateAddressUseCase createAddress;
  final SetDefaultAddressUseCase setDefault;
  final DeleteAddressUseCase deleteAddress;

  AddressBloc({
    required this.getAddresses,
    required this.createAddress,
    required this.setDefault,
    required this.deleteAddress,
  }) : super(const AddressInitial()) {
    on<LoadAddressesEvent>(_onLoad);
    on<CreateAddressEvent>(_onCreate);
    on<SetDefaultAddressEvent>(_onSetDefault);
    on<DeleteAddressEvent>(_onDelete);
  }

  Future<void> _onLoad(
    LoadAddressesEvent event,
    Emitter<AddressState> emit,
  ) async {
    emit(const AddressLoading());
    try {
      final addresses = await getAddresses();
      emit(AddressLoaded(addresses));
    } catch (e) {
      AppLogger.error('Failed to load addresses', e);
      emit(AddressError(e.toString()));
    }
  }

  Future<void> _onCreate(
    CreateAddressEvent event,
    Emitter<AddressState> emit,
  ) async {
    emit(const AddressLoading());
    try {
      await createAddress(event.params);
      final addresses = await getAddresses();
      emit(AddressOperationSuccess(
        addresses: addresses,
        message: 'Dirección creada correctamente',
      ));
    } catch (e) {
      AppLogger.error('Failed to create address', e);
      emit(AddressError(e.toString()));
    }
  }

  Future<void> _onSetDefault(
    SetDefaultAddressEvent event,
    Emitter<AddressState> emit,
  ) async {
    emit(const AddressLoading());
    try {
      await setDefault(event.addressId);
      final addresses = await getAddresses();
      emit(AddressOperationSuccess(
        addresses: addresses,
        message: 'Dirección predeterminada actualizada',
      ));
    } catch (e) {
      AppLogger.error('Failed to set default address', e);
      emit(AddressError(e.toString()));
    }
  }

  Future<void> _onDelete(
    DeleteAddressEvent event,
    Emitter<AddressState> emit,
  ) async {
    emit(const AddressLoading());
    try {
      await deleteAddress(event.addressId);
      final addresses = await getAddresses();
      emit(AddressOperationSuccess(
        addresses: addresses,
        message: 'Dirección eliminada',
      ));
    } catch (e) {
      AppLogger.error('Failed to delete address', e);
      emit(AddressError(e.toString()));
    }
  }
}
