import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String? documentId;
  final String? profilePhotoUrl;
  final String role;
  final String status;
  final bool emailVerified;
  final bool phoneVerified;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const User({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.documentId,
    this.profilePhotoUrl,
    required this.role,
    required this.status,
    required this.emailVerified,
    required this.phoneVerified,
    required this.createdAt,
    this.lastLoginAt,
  });

  @override
  List<Object?> get props => [
    id,
    email,
    fullName,
    phoneNumber,
    documentId,
    profilePhotoUrl,
    role,
    status,
    emailVerified,
    phoneVerified,
    createdAt,
    lastLoginAt,
  ];

  bool get isClient => role == 'client' || role == 'CLIENT';

  bool get isProvider => role == 'provider' || role == 'PROVIDER';

  bool get isActive => status == 'ACTIVE';
}
