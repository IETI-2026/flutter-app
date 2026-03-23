import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/core/services/websocket_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

class ServiceMapPage extends StatefulWidget {
  final String requestId;
  final String technicianId;
  final String tenantId;
  final double clientLatitude;
  final double clientLongitude;
  final Map<String, dynamic> clientInfo;
  final String serviceStatus;
  final DateTime? startedAt;
  final bool technicianMarkedComplete;
  final bool clientMarkedComplete;
  final double? initialTechLatitude;
  final double? initialTechLongitude;
  // When true, this page is opened by the client: device GPS tracks client
  // location and tech position is received via WebSocket events.
  final bool isClientView;
  // The client's own userId, used for location updates in client view.
  final String? clientUserId;

  const ServiceMapPage({
    super.key,
    required this.requestId,
    required this.technicianId,
    required this.tenantId,
    required this.clientLatitude,
    required this.clientLongitude,
    required this.clientInfo,
    required this.serviceStatus,
    this.startedAt,
    this.technicianMarkedComplete = false,
    this.clientMarkedComplete = false,
    this.initialTechLatitude,
    this.initialTechLongitude,
    this.isClientView = false,
    this.clientUserId,
  });

  @override
  State<ServiceMapPage> createState() => _ServiceMapPageState();
}

class _ServiceMapPageState extends State<ServiceMapPage> {
  late final MapController _mapController;
  LatLng? _technicianLocation;
  LatLng _clientLocation = const LatLng(0, 0);
  Timer? _locationTimer;
  Timer? _timerTick;
  int _elapsedSeconds = 0;
  String _currentStatus = '';
  bool _technicianMarkedComplete = false;
  bool _clientMarkedComplete = false;
  bool _markingComplete = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _clientLocation = LatLng(widget.clientLatitude, widget.clientLongitude);
    _currentStatus = widget.serviceStatus;
    _technicianMarkedComplete = widget.technicianMarkedComplete;
    _clientMarkedComplete = widget.clientMarkedComplete;

    if (widget.initialTechLatitude != null &&
        widget.initialTechLongitude != null) {
      _technicianLocation = LatLng(
        widget.initialTechLatitude!,
        widget.initialTechLongitude!,
      );
    }

    if (_currentStatus == 'IN_PROGRESS' && widget.startedAt != null) {
      _elapsedSeconds =
          DateTime.now().difference(widget.startedAt!).inSeconds;
      _startTimer();
    }

    _joinRoom();
    _listenToWebSocket();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _timerTick?.cancel();
    sl<WebSocketService>().offLocationUpdated();
    sl<WebSocketService>().offServiceStatusUpdated();
    super.dispose();
  }

  void _joinRoom() {
    sl<WebSocketService>().joinRequestRoom(widget.requestId);
  }

  void _listenToWebSocket() {
    sl<WebSocketService>().onLocationUpdated((data) {
      if (!mounted) return;
      final role = data['role']?.toString();
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return;

      if (widget.isClientView) {
        // Client is viewing: tech location arrives via WS events.
        if (role == 'technician') {
          setState(() => _technicianLocation = LatLng(lat, lng));
        }
      } else {
        // Technician is viewing: client location arrives via WS events.
        if (role == 'client') {
          setState(() => _clientLocation = LatLng(lat, lng));
        }
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
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
        if (!mounted) return;
        final String userId = widget.isClientView
            ? (widget.clientUserId ?? widget.technicianId)
            : widget.technicianId;
        setState(() {
          if (widget.isClientView) {
            _clientLocation = LatLng(pos.latitude, pos.longitude);
          } else {
            _technicianLocation = LatLng(pos.latitude, pos.longitude);
          }
        });
        await sl<Dio>().patch(
          '/service-requests/${widget.requestId}/update-location',
          data: {
            'userId': userId,
            'latitude': pos.latitude,
            'longitude': pos.longitude,
          },
          options: Options(
            headers: {'X-Tenant-ID': widget.tenantId},
          ),
        );
      } catch (_) {}
    });
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

  Future<void> _markComplete() async {
    setState(() => _markingComplete = true);
    final String userId = widget.isClientView
        ? (widget.clientUserId ?? '')
        : widget.technicianId;
    final String role = widget.isClientView ? 'client' : 'technician';
    try {
      await sl<Dio>().patch(
        '/service-requests/${widget.requestId}/mark-complete',
        data: {'userId': userId, 'role': role},
        options: Options(headers: {'X-Tenant-ID': widget.tenantId}),
      );
      if (!mounted) return;
      setState(() {
        if (widget.isClientView) {
          _clientMarkedComplete = true;
        } else {
          _technicianMarkedComplete = true;
        }
      });
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

  Widget _buildClientBottomPanel(ColorScheme colorScheme) {
    final isInProgress = _currentStatus == 'IN_PROGRESS';
    final statusLabel = switch (_currentStatus) {
      'ON_THE_WAY' => 'Técnico en camino',
      'IN_PROGRESS' => 'Servicio en progreso',
      _ => _currentStatus,
    };
    final statusColor = isInProgress ? AppColors.success : AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showComingSoon,
                icon: const Icon(Icons.chat_outlined, size: 18),
                label: Text('Chatear', style: GoogleFonts.poppins()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (isInProgress) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _clientMarkedComplete || _markingComplete
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
                    _clientMarkedComplete ? 'Finalizado' : 'Marcar finalizado',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _clientMarkedComplete ? AppColors.grey : AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTechnicianBottomPanel(
    ColorScheme colorScheme,
    String clientName,
    String? clientPhone,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Información del cliente',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                clientName.isNotEmpty ? clientName[0].toUpperCase() : 'C',
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clientName,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (clientPhone != null)
                    Text(
                      clientPhone,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showComingSoon,
                icon: const Icon(Icons.chat_outlined, size: 18),
                label: Text('Chatear', style: GoogleFonts.poppins()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    _technicianMarkedComplete || _markingComplete
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
                        _technicianMarkedComplete
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        size: 18,
                      ),
                label: Text(
                  _technicianMarkedComplete ? 'Finalizado' : 'Marcar finalizado',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _technicianMarkedComplete
                          ? AppColors.grey
                          : AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (_currentStatus) {
      'ON_THE_WAY' => 'Asignado',
      'IN_PROGRESS' => 'En progreso',
      _ => _currentStatus,
    };

    final statusColor = _currentStatus == 'IN_PROGRESS'
        ? AppColors.success
        : AppColors.primary;

    final clientName =
        widget.clientInfo['fullName']?.toString() ?? 'Cliente';
    final clientPhone =
        widget.clientInfo['phoneNumber']?.toString();

    final colorScheme = Theme.of(context).colorScheme;
    final techPoint = _technicianLocation ?? _clientLocation;
    return Builder(
      builder: (context) {

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Mapa del servicio',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            elevation: 0,
            actions: [
              if (_currentStatus == 'IN_PROGRESS')
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
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
          body: Column(
            children: [
              // Status banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
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

              // Bottom panel
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
                child: widget.isClientView
                    ? _buildClientBottomPanel(colorScheme)
                    : _buildTechnicianBottomPanel(
                        colorScheme,
                        clientName,
                        clientPhone,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
