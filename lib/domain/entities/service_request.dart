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
  final DateTime? completedAt;
  final bool clientMarkedComplete;
  final bool technicianMarkedComplete;
  final double? displacementDistanceKm;
  final double? finalPrice;
  final String? technicianName;
  final String? technicianPhotoUrl;
  final String? categoryName;

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
    this.completedAt,
    this.clientMarkedComplete = false,
    this.technicianMarkedComplete = false,
    this.displacementDistanceKm,
    this.finalPrice,
    this.technicianName,
    this.technicianPhotoUrl,
    this.categoryName,
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
      completedAt: completedAt,
      clientMarkedComplete: clientMarkedComplete,
      technicianMarkedComplete: technicianMarkedComplete,
      displacementDistanceKm: displacementDistanceKm,
      finalPrice: finalPrice,
      technicianName: technicianName,
      technicianPhotoUrl: technicianPhotoUrl,
      categoryName: categoryName,
    );
  }

  @override
  List<Object?> get props => [id, userId, problema, status, createdAt];
}
