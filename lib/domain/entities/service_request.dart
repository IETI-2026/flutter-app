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
  final DateTime? startedAt;
  final bool clientMarkedComplete;
  final bool technicianMarkedComplete;

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
    this.startedAt,
    this.clientMarkedComplete = false,
    this.technicianMarkedComplete = false,
  });

  ServiceRequest copyWith({String? status}) {
    return ServiceRequest(
      id: id,
      userId: userId,
      assignedTechnicianId: assignedTechnicianId,
      problema: problema,
      status: status ?? this.status,
      urgency: urgency,
      requestedSkills: requestedSkills,
      latitude: latitude,
      longitude: longitude,
      addressText: addressText,
      serviceCity: serviceCity,
      createdAt: createdAt,
      updatedAt: updatedAt,
      startedAt: startedAt,
      clientMarkedComplete: clientMarkedComplete,
      technicianMarkedComplete: technicianMarkedComplete,
    );
  }

  @override
  List<Object?> get props => [id, userId, problema, status, createdAt];
}
