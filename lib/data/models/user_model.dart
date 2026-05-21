import 'package:flutter_app/domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.fullName,
    super.phoneNumber,
    super.documentId,
    super.profilePhotoUrl,
    required super.role,
    required super.status,
    required super.emailVerified,
    required super.phoneVerified,
    required super.createdAt,
    super.lastLoginAt,
  });

  /// API Nest puede enviar `role` o `roles: ["USER","PROVIDER",...]`.
  static String _roleFromJson(Map<String, dynamic> json) {
    final direct = json['role'];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct.trim();
    }
    final roles = json['roles'];
    if (roles is List) {
      for (final r in roles) {
        final s = r.toString().toUpperCase();
        if (s.contains('PROVIDER')) return 'provider';
      }
      for (final r in roles) {
        final s = r.toString().toUpperCase();
        if (s.contains('CLIENT')) return 'client';
      }
    }
    return 'client';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? json['name'] ?? '',
      phoneNumber: json['phoneNumber'],
      documentId: json['documentId'],
      profilePhotoUrl: json['profilePhotoUrl'],
      role: _roleFromJson(json),
      status: json['status'] ?? 'ACTIVE',
      emailVerified: json['emailVerified'] ?? false,
      phoneVerified: json['phoneVerified'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'documentId': documentId,
      'profilePhotoUrl': profilePhotoUrl,
      'role': role,
      'status': status,
      'emailVerified': emailVerified,
      'phoneVerified': phoneVerified,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  User toEntity() {
    return User(
      id: id,
      email: email,
      fullName: fullName,
      phoneNumber: phoneNumber,
      documentId: documentId,
      profilePhotoUrl: profilePhotoUrl,
      role: role,
      status: status,
      emailVerified: emailVerified,
      phoneVerified: phoneVerified,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
    );
  }
}
