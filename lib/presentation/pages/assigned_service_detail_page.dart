import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/core/services/websocket_service.dart';
import 'package:flutter_app/presentation/widgets/profile_photo_widget.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

class AssignedServiceDetailPage extends StatefulWidget {
  final String requestId;
  final String clientUserId;
  final String tenantId;
  final String serviceStatus;
  final DateTime? startedAt;
  final bool clientMarkedComplete;
  final double clientLatitude;
  final double clientLongitude;

  const AssignedServiceDetailPage({
    super.key,
    required this.requestId,
    required this.clientUserId,
    required this.tenantId,
    required this.serviceStatus,
    this.startedAt,
    this.clientMarkedComplete = false,
    required this.clientLatitude,
    required this.clientLongitude,
  });

  @override
  State<AssignedServiceDetailPage> createState() =>
      _AssignedServiceDetailPageState();
}

class _AssignedServiceDetailPageState extends State<AssignedServiceDetailPage> {
  late final MapController _mapController;
  Map<String, dynamic>? _technician;
  bool _loading = true;
  String _currentStatus = '';
  bool _clientMarkedComplete = false;
  bool _markingComplete = false;
  int _elapsedSeconds = 0;
  Timer? _timerTick;
  Timer? _locationTimer;

  LatLng? _technicianLocation;
  late LatLng _clientLocation;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentStatus = widget.serviceStatus;
    _clientMarkedComplete = widget.clientMarkedComplete;
    _clientLocation = LatLng(widget.clientLatitude, widget.clientLongitude);

    if (_currentStatus == 'IN_PROGRESS' && widget.startedAt != null) {
      _elapsedSeconds =
          DateTime.now().difference(widget.startedAt!).inSeconds;
      _startTimer();
    }

    _loadTechnician();
    _listenToWebSocket();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _timerTick?.cancel();
    _locationTimer?.cancel();
    sl<WebSocketService>().offServiceStatusUpdated();
    sl<WebSocketService>().offLocationUpdated();
    super.dispose();
  }

  void _listenToWebSocket() {
    sl<WebSocketService>().joinRequestRoom(widget.requestId);

    sl<WebSocketService>().onLocationUpdated((data) {
      if (!mounted) return;
      final role = data['role']?.toString();
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      if (role == 'technician') {
        setState(() => _technicianLocation = LatLng(lat, lng));
      }
    });

    sl<WebSocketService>().onServiceStatusUpdated((data) {
      if (!mounted) return;
      final newStatus = data['status']?.toString() ?? '';
      setState(() => _currentStatus = newStatus);
      if (newStatus == 'IN_PROGRESS' && _timerTick == null) {
        _elapsedSeconds = 0;
        _startTimer();
      }
    });
  }

  void _startTimer() {
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
        if (!mounted) return;
        setState(() => _clientLocation = LatLng(pos.latitude, pos.longitude));
        await sl<Dio>().patch(
          '/service-requests/${widget.requestId}/update-location',
          data: {
            'latitude': pos.latitude,
            'longitude': pos.longitude,
          },
          options: Options(headers: {'X-Tenant-ID': widget.tenantId}),
        );
      } catch (_) {}
    });
  }

  Future<void> _loadTechnician() async {
    try {
      final response = await sl<Dio>().get(
        '/service-requests/${widget.requestId}/accepted-technicians',
        options: Options(headers: {'X-Tenant-ID': widget.tenantId}),
      );
      final data = response.data;
      if (data is List && data.isNotEmpty) {
        final tech = Map<String, dynamic>.from(data.first as Map);
        final lat = (tech['currentLatitude'] as num?)?.toDouble();
        final lng = (tech['currentLongitude'] as num?)?.toDouble();
        setState(() {
          _technician = tech;
          _loading = false;
          if (lat != null && lng != null) {
            _technicianLocation = LatLng(lat, lng);
          }
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _markComplete() async {
    setState(() => _markingComplete = true);
    try {
      await sl<Dio>().patch(
        '/service-requests/${widget.requestId}/mark-complete',
        data: {'role': 'client'},
        options: Options(headers: {'X-Tenant-ID': widget.tenantId}),
      );
      if (!mounted) return;
      setState(() => _clientMarkedComplete = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marcaste el servicio como finalizado'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al marcar como finalizado')),
      );
    } finally {
      if (mounted) setState(() => _markingComplete = false);
    }
  }

  void _showComingSoon() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Chat'),
        content: const Text('Próximamente disponible'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusLabel = switch (_currentStatus) {
      'ON_THE_WAY' => 'En camino',
      'IN_PROGRESS' => 'En progreso',
      _ => _currentStatus,
    };
    final statusColor =
        _currentStatus == 'IN_PROGRESS' ? AppColors.success : AppColors.primary;

    final techName =
        _technician?['fullName']?.toString() ?? 'Técnico asignado';
    final techPhone = _technician?['phoneNumber']?.toString();
    final techPhoto = _technician?['profilePhotoUrl']?.toString();
    final techSkills = (_technician?['skills'] as List?)
            ?.map((s) => s.toString())
            .toList() ??
        [];

    final techPoint = _technicianLocation ?? _clientLocation;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Técnico Asignado',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          if (_currentStatus == 'IN_PROGRESS')
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(_elapsedSeconds),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadTechnician,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
          // Status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: statusColor.withValues(alpha: 0.1),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            flex: 3,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: techPoint,
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.cameyo.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [techPoint, _clientLocation],
                      color: AppColors.primary.withValues(alpha: 0.6),
                      strokeWidth: 3,
                      pattern: StrokePattern.dashed(
                        segments: const [12, 8],
                      ),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: techPoint,
                      width: 48,
                      height: 48,
                      child: const Icon(
                        Icons.engineering,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    Marker(
                      point: _clientLocation,
                      width: 48,
                      height: 48,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Technician info + actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Técnico asignado',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ProfilePhotoWidget(
                            photoUrl: techPhoto,
                            name: techName,
                            radius: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  techName,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                if (techPhone != null)
                                  Text(
                                    techPhone,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (techSkills.isNotEmpty)
                            Wrap(
                              spacing: 4,
                              children: techSkills
                                  .take(2)
                                  .map(
                                    (s) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        s,
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showComingSoon,
                              icon: const Icon(Icons.chat_outlined, size: 18),
                              label: Text(
                                'Chatear',
                                style: GoogleFonts.poppins(),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _clientMarkedComplete || _markingComplete
                                      ? null
                                      : _markComplete,
                              icon: _markingComplete
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      _clientMarkedComplete
                                          ? Icons.check_circle
                                          : Icons.check_circle_outline,
                                      size: 18,
                                    ),
                              label: Text(
                                _clientMarkedComplete
                                    ? 'Finalizado'
                                    : 'Marcar finalizado',
                                style: GoogleFonts.poppins(fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _clientMarkedComplete
                                    ? AppColors.grey
                                    : AppColors.success,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
