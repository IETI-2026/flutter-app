import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/core/services/websocket_service.dart';
import 'package:flutter_app/core/utils/logger.dart';
import 'package:flutter_app/data/datasources/auth_local_datasource.dart';

class RequestedServiceTechniciansPage extends StatefulWidget {
  final String requestId;
  final String clientUserId;
  final String tenantId;
  final double? requestLatitude;
  final double? requestLongitude;

  const RequestedServiceTechniciansPage({
    super.key,
    required this.requestId,
    required this.clientUserId,
    required this.tenantId,
    this.requestLatitude,
    this.requestLongitude,
  });

  @override
  State<RequestedServiceTechniciansPage> createState() =>
      _RequestedServiceTechniciansPageState();
}

class _RequestedServiceTechniciansPageState
    extends State<RequestedServiceTechniciansPage> {
  List<Map<String, dynamic>> _technicians = [];
  bool _loading = true;
  String? _error;
  String? _choosingId;

  @override
  void initState() {
    super.initState();
    _loadTechnicians();
    _setupWebSocket();
  }

  @override
  void dispose() {
    sl<WebSocketService>().offTechnicianAccepted();
    super.dispose();
  }

  Future<void> _loadTechnicians() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await sl<Dio>().get(
        '/service-requests/${widget.requestId}/accepted-technicians',
      );
      final data = response.data;
      if (!mounted) return;
      final List<dynamic> raw = data is List ? data : [];
      setState(() {
        _technicians = raw
            .whereType<Map<String, dynamic>>()
            .toList();
        _sortByDistance();
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.response?.data is Map<String, dynamic>
            ? e.response?.data['message']?.toString()
            : 'Error ${e.response?.statusCode ?? 'de red'}';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _setupWebSocket() async {
    final wsService = sl<WebSocketService>();
    if (!wsService.isConnected) {
      final token = await sl<AuthLocalDataSource>().getAccessToken();
      wsService.connect(token: token);
    }

    wsService.joinRequestRoom(widget.requestId);

    wsService.onTechnicianAccepted((data) {
      if (!mounted) return;
      setState(() {
        final techId = data['id']?.toString();
        final alreadyExists =
            _technicians.any((t) => t['id']?.toString() == techId);
        if (!alreadyExists) {
          _technicians.add(data);
          _sortByDistance();
        }
      });
    });
  }

  void _sortByDistance() {
    if (widget.requestLatitude == null || widget.requestLongitude == null) {
      return;
    }
    _technicians.sort((a, b) {
      final distA = _calcDistance(a);
      final distB = _calcDistance(b);
      return distA.compareTo(distB);
    });
  }

  double _calcDistance(Map<String, dynamic> technician) {
    final lat = (technician['currentLatitude'] as num?)?.toDouble();
    final lng = (technician['currentLongitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return double.infinity;
    if (widget.requestLatitude == null || widget.requestLongitude == null) {
      return double.infinity;
    }
    return _haversineDistance(
      widget.requestLatitude!,
      widget.requestLongitude!,
      lat,
      lng,
    );
  }

  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _toRad(double deg) => deg * math.pi / 180;

  String _formatDistance(Map<String, dynamic> technician) {
    final dist = _calcDistance(technician);
    if (dist == double.infinity) return 'Distancia desconocida';
    if (dist < 1000) return '${dist.toStringAsFixed(0)} m';
    return '${(dist / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _chooseTechnician(String technicianId) async {
    setState(() => _choosingId = technicianId);
    try {
      await sl<Dio>().patch(
        '/service-requests/${widget.requestId}/choose-technician',
        data: {
          'technicianUserId': technicianId,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map<String, dynamic>
          ? e.response?.data['message']?.toString()
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg ?? 'Error al contratar técnico'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      AppLogger.error('chooseTechnician error', e);
    } finally {
      if (mounted) setState(() => _choosingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Técnicos disponibles',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onSurface),
            onPressed: _loadTechnicians,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadTechnicians,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_technicians.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.engineering_outlined,
              size: 72,
              color: AppColors.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Esperando técnicos...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Los técnicos que acepten tu solicitud aparecerán aquí en tiempo real.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            const _PulsingIndicator(),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: Theme.of(context).appBarTheme.backgroundColor,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              const Icon(
                Icons.people_outline,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '${_technicians.length} técnico${_technicians.length == 1 ? '' : 's'} disponible${_technicians.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              const _PulsingIndicator(),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadTechnicians,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: _technicians.length,
              itemBuilder: (context, index) {
                return _TechnicianCard(
                  technician: _technicians[index],
                  distance: _formatDistance(_technicians[index]),
                  isChoosing: _choosingId ==
                      _technicians[index]['id']?.toString(),
                  onChoose: () => _chooseTechnician(
                    _technicians[index]['id']?.toString() ?? '',
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ── TECHNICIAN CARD ──────────────────────────────────────────────────────────

class _TechnicianCard extends StatelessWidget {
  final Map<String, dynamic> technician;
  final String distance;
  final bool isChoosing;
  final VoidCallback onChoose;

  const _TechnicianCard({
    required this.technician,
    required this.distance,
    required this.isChoosing,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    final fullName = technician['fullName']?.toString() ?? 'Técnico';
    final photoUrl = technician['profilePhotoUrl']?.toString();
    final skills = (technician['skills'] as List?)
            ?.map((s) => s.toString())
            .toList() ??
        [];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(
                          fullName.isNotEmpty
                              ? fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            technician['averageRating'] != null
                                ? (technician['averageRating'] as num)
                                    .toStringAsFixed(1)
                                : '-',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            distance,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (skills.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: skills
                    .take(4)
                    .map(
                      (skill) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          skill,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isChoosing ? null : onChoose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isChoosing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Text(
                        'Contratar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── PULSING INDICATOR ────────────────────────────────────────────────────────

class _PulsingIndicator extends StatefulWidget {
  const _PulsingIndicator();

  @override
  State<_PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<_PulsingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: _animation.value),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'En tiempo real',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.success.withValues(alpha: _animation.value),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
