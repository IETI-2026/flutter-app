import 'package:flutter_app/domain/entities/address.dart';

class AddressModel extends Address {
  const AddressModel({
    required super.id,
    required super.userId,
    required super.street,
    required super.city,
    super.neighborhood,
    super.department,
    required super.country,
    super.postalCode,
    super.label,
    super.latitude,
    super.longitude,
    required super.isDefault,
    required super.createdAt,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      street: json['street'] as String,
      city: json['city'] as String,
      neighborhood: json['neighborhood'] as String?,
      department: json['department'] as String?,
      country: (json['country'] as String?) ?? 'CO',
      postalCode: json['postalCode'] as String?,
      label: json['label'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isDefault: (json['isDefault'] as bool?) ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'street': street,
      'city': city,
      'neighborhood': neighborhood,
      'department': department,
      'country': country,
      'postalCode': postalCode,
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
