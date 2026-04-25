import 'package:equatable/equatable.dart';

class Address extends Equatable {
  final String id;
  final String userId;
  final String street;
  final String city;
  final String? neighborhood;
  final String? department;
  final String country;
  final String? postalCode;
  final String? label;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final DateTime createdAt;

  const Address({
    required this.id,
    required this.userId,
    required this.street,
    required this.city,
    this.neighborhood,
    this.department,
    required this.country,
    this.postalCode,
    this.label,
    this.latitude,
    this.longitude,
    required this.isDefault,
    required this.createdAt,
  });

  String get displayName {
    final parts = <String>[street, city];
    if (neighborhood != null && neighborhood!.isNotEmpty) {
      parts.insert(1, neighborhood!);
    }
    return parts.join(', ');
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  @override
  List<Object?> get props => [
    id,
    userId,
    street,
    city,
    neighborhood,
    department,
    country,
    postalCode,
    label,
    latitude,
    longitude,
    isDefault,
    createdAt,
  ];
}
