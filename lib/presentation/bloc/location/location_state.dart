import 'package:equatable/equatable.dart';

abstract class LocationState extends Equatable {
  const LocationState();

  @override
  List<Object?> get props => [];
}

class LocationInitial extends LocationState {
  const LocationInitial();
}

class LocationLoading extends LocationState {
  const LocationLoading();
}

class LocationLoaded extends LocationState {
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String serviceCity;

  const LocationLoaded({
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.serviceCity,
  });

  @override
  List<Object?> get props => [
    formattedAddress,
    latitude,
    longitude,
    serviceCity,
  ];
}

class LocationOptimistic extends LocationState {
  final String displayLabel;
  final double latitude;
  final double longitude;

  const LocationOptimistic({
    required this.displayLabel,
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [displayLabel, latitude, longitude];
}

class LocationError extends LocationState {
  final String message;

  const LocationError({required this.message});

  @override
  List<Object?> get props => [message];
}
