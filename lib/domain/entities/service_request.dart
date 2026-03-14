import 'package:equatable/equatable.dart';

class ServiceRequest extends Equatable {
  final String id;
  final String userId;
  final String? assignedTechnicianId;
  final String problema;
  final String status;
  final String? urgency;
  final List<String> requestedSkills;
  final double? latitude;
  final double? longitude;
  final String? addressText;
  final String? serviceCity;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ServiceRequest({
    required this.id,
    required this.userId,
    this.assignedTechnicianId,
    required this.problema,
    required this.status,
    this.urgency,
    this.requestedSkills = const [],
    this.latitude,
    this.longitude,
    this.addressText,
    this.serviceCity,
    required this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [id, userId, problema, status, createdAt];
}
