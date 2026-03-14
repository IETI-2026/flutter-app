import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/domain/entities/service_request.dart';
import 'package:flutter_app/presentation/pages/requested_service_technicians_page.dart';

const _kStatuses = [
  'REQUESTED',
  'ASSIGNED',
  'ON_THE_WAY',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
  'FAILED',
];

const _kStatusLabels = {
  'REQUESTED': 'Solicitada',
  'ASSIGNED': 'Asignada',
  'ON_THE_WAY': 'En camino',
  'IN_PROGRESS': 'En progreso',
  'COMPLETED': 'Completada',
  'CANCELLED': 'Cancelada',
  'FAILED': 'Fallida',
};

class ServiceRequestsPage extends StatefulWidget {
  final String userId;
  final int refreshToken;
  final bool embedded;
  final String? tenantId;

  const ServiceRequestsPage({
    super.key,
    required this.userId,
    this.refreshToken = 0,
    this.embedded = false,
    this.tenantId,
  });

  @override
  State<ServiceRequestsPage> createState() => _ServiceRequestsPageState();
}

class _ServiceRequestsPageState extends State<ServiceRequestsPage> {
  String? _statusFilter;
  final _cityController = TextEditingController();
  final _technicianController = TextEditingController();
  bool _filtersExpanded = false;

  int _page = 0;
  static const int _limit = 20;
  int _total = 0;

  List<ServiceRequest> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  @override
  void didUpdateWidget(covariant ServiceRequestsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId) {
      _fetchRequests(resetPage: true);
      return;
    }

    if (oldWidget.refreshToken != widget.refreshToken) {
      _fetchRequests(resetPage: true);
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    _technicianController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequests({bool resetPage = false}) async {
    if (resetPage) {
      _page = 0;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final params = <String, dynamic>{
        'userId': widget.userId,
        'page': _page,
        'limit': _limit,
      };

      if (_statusFilter != null) {
        params['status'] = _statusFilter;
      }

      final city = _cityController.text.trim();
      if (city.isNotEmpty) {
        params['serviceCity'] = city;
      }

      final technicianId = _technicianController.text.trim();
      if (technicianId.isNotEmpty) {
        params['technicianUserId'] = technicianId;
      }

      final response = await sl<Dio>().get(
        '/service-requests',
        queryParameters: params,
        options: widget.tenantId != null && widget.tenantId!.isNotEmpty
            ? Options(headers: {'X-Tenant-ID': widget.tenantId})
            : null,
      );

      final data = response.data;
      List<dynamic> rawRequests = [];
      var total = 0;

      if (data is Map<String, dynamic>) {
        rawRequests = (data['requests'] ?? []) as List<dynamic>;
        total = (data['total'] as num?)?.toInt() ?? rawRequests.length;
      } else if (data is List) {
        rawRequests = data;
        total = rawRequests.length;
      }

      final parsedRequests = rawRequests
          .whereType<Map<String, dynamic>>()
          .map(_parseServiceRequest)
          .toList()
        ..sort((a, b) {
          final aDate = a.updatedAt ?? a.createdAt;
          final bDate = b.updatedAt ?? b.createdAt;
          return bDate.compareTo(aDate);
        });

      if (!mounted) {
        return;
      }

      setState(() {
        _requests = parsedRequests;
        _total = total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        if (e is DioException) {
          final serverMessage = e.response?.data is Map<String, dynamic>
              ? e.response?.data['message']?.toString()
              : null;
          _error = serverMessage ?? 'Error ${e.response?.statusCode ?? 'de red'}';
        } else {
          _error = e.toString();
        }
        _loading = false;
      });
    }
  }

  ServiceRequest _parseServiceRequest(Map<String, dynamic> json) {
    final skills = json['requestedSkills'];

    return ServiceRequest(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      assignedTechnicianId: json['assignedTechnicianId']?.toString(),
      problema:
          json['problema']?.toString() ?? json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'UNKNOWN',
      urgency: json['urgency']?.toString(),
      requestedSkills: skills is List
          ? skills.map((skill) => skill.toString()).toList()
          : const [],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      addressText: json['addressText']?.toString(),
      serviceCity: json['serviceCity']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  void _applyFilters() {
    FocusScope.of(context).unfocus();
    _fetchRequests(resetPage: true);
  }

  void _resetFilters() {
    setState(() {
      _statusFilter = null;
      _cityController.clear();
      _technicianController.clear();
    });
    _fetchRequests(resetPage: true);
  }

  bool get _hasActiveFilters {
    return _statusFilter != null ||
        _cityController.text.trim().isNotEmpty ||
        _technicianController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Container(
        color: AppColors.backgroundLight,
        child: Column(
          children: [
            _FilterPanel(
              expanded: _filtersExpanded,
              statusFilter: _statusFilter,
              cityController: _cityController,
              technicianController: _technicianController,
              onStatusChanged: (status) {
                setState(() {
                  _statusFilter = status;
                });
              },
              onApply: _applyFilters,
              onReset: _resetFilters,
              hasActiveFilters: _hasActiveFilters,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Mis Servicios',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Filtros',
            onPressed: () {
              setState(() {
                _filtersExpanded = !_filtersExpanded;
              });
            },
            icon: Badge(
              isLabelVisible: _hasActiveFilters,
              child: Icon(
                _filtersExpanded ? Icons.filter_list_off : Icons.filter_list,
                color: _hasActiveFilters
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterPanel(
            expanded: _filtersExpanded,
            statusFilter: _statusFilter,
            cityController: _cityController,
            technicianController: _technicianController,
            onStatusChanged: (status) {
              setState(() {
                _statusFilter = status;
              });
            },
            onApply: _applyFilters,
            onReset: _resetFilters,
            hasActiveFilters: _hasActiveFilters,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
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
              const Text(
                'No se pudieron cargar los servicios',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _fetchRequests(resetPage: true),
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

    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 72,
              color: AppColors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No se encontraron servicios',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Prueba ajustando los filtros',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _fetchRequests(resetPage: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: _requests.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildSummaryRow();
          }
          final request = _requests[index - 1];
          final canOpenTechnicians = request.status.toUpperCase() == 'REQUESTED';
          return _ServiceRequestCard(
            request: request,
            onTap: canOpenTechnicians
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RequestedServiceTechniciansPage(
                          requestId: request.id,
                        ),
                      ),
                    );
                  }
                : null,
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow() {
    final start = _requests.isEmpty ? 0 : _page * _limit + 1;
    final end = (_page * _limit + _requests.length).clamp(0, _total);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$start-$end de $_total ${_total == 1 ? 'solicitud' : 'solicitudes'}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Row(
            children: [
              _PaginationButton(
                icon: Icons.chevron_left,
                enabled: _page > 0,
                onTap: () {
                  _page--;
                  _fetchRequests();
                },
              ),
              const SizedBox(width: 4),
              Text(
                'Pág. ${_page + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              _PaginationButton(
                icon: Icons.chevron_right,
                enabled: end < _total,
                onTap: () {
                  _page++;
                  _fetchRequests();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final bool expanded;
  final String? statusFilter;
  final TextEditingController cityController;
  final TextEditingController technicianController;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;
  final bool hasActiveFilters;

  const _FilterPanel({
    required this.expanded,
    required this.statusFilter,
    required this.cityController,
    required this.technicianController,
    required this.onStatusChanged,
    required this.onApply,
    required this.onReset,
    required this.hasActiveFilters,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 220),
      crossFadeState:
          expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstChild: const SizedBox.shrink(),
      secondChild: Container(
        color: AppColors.white,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1, color: AppColors.greyLight),
            const SizedBox(height: 12),
            const Text(
              'Estado',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _kStatuses.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final status = _kStatuses[index];
                  final selected = statusFilter == status;
                  return GestureDetector(
                    onTap: () => onStatusChanged(selected ? null : status),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? _statusColor(status).withOpacity(0.15)
                            : AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? _statusColor(status)
                              : AppColors.greyLight,
                        ),
                      ),
                      child: Text(
                        _kStatusLabels[status] ?? status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? _statusColor(status)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _FilterTextField(
                    controller: cityController,
                    label: 'Ciudad',
                    hint: 'ej. cajica',
                    icon: Icons.location_city_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FilterTextField(
                    controller: technicianController,
                    label: 'ID Técnico',
                    hint: 'UUID del técnico',
                    icon: Icons.engineering_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (hasActiveFilters)
                  OutlinedButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Limpiar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.greyLight),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                if (hasActiveFilters) const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApply,
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('Buscar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'REQUESTED':
        return AppColors.warning;
      case 'ASSIGNED':
        return AppColors.info;
      case 'ON_THE_WAY':
        return AppColors.primary;
      case 'IN_PROGRESS':
        return AppColors.secondary;
      case 'COMPLETED':
        return AppColors.success;
      case 'CANCELLED':
      case 'FAILED':
        return AppColors.error;
      default:
        return AppColors.grey;
    }
  }
}

class _FilterTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  const _FilterTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
            ),
            prefixIcon: Icon(icon, size: 16, color: AppColors.grey),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 10,
              horizontal: 10,
            ),
            filled: true,
            fillColor: AppColors.backgroundLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.greyLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.greyLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PaginationButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.greyLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.primary : AppColors.grey,
        ),
      ),
    );
  }
}

class _ServiceRequestCard extends StatelessWidget {
  final ServiceRequest request;
  final VoidCallback? onTap;

  const _ServiceRequestCard({required this.request, this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusInfo(request.status);
    final urgencyInfo = _urgencyInfo(request.urgency);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.build_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.problema,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(request.updatedAt ?? request.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(label: statusInfo.label, color: statusInfo.color),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.greyLight),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (request.requestedSkills.isNotEmpty)
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: request.requestedSkills
                          .map((skill) => _SkillChip(label: skill))
                          .toList(),
                    ),
                  ),
                if (urgencyInfo != null) ...[
                  if (request.requestedSkills.isNotEmpty)
                    const SizedBox(width: 8),
                  _StatusBadge(
                    label: urgencyInfo.label,
                    color: urgencyInfo.color,
                  ),
                ],
              ],
            ),
            if (request.addressText != null && request.addressText!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      request.addressText!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (request.assignedTechnicianId != null) ...[
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(
                    Icons.engineering_outlined,
                    size: 14,
                    color: AppColors.success,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Técnico asignado',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year} · $hour:$minute';
  }

  ({String label, Color color}) _statusInfo(String status) {
    switch (status.toUpperCase()) {
      case 'REQUESTED':
        return (label: 'Solicitada', color: AppColors.warning);
      case 'ASSIGNED':
        return (label: 'Asignada', color: AppColors.info);
      case 'ON_THE_WAY':
        return (label: 'En camino', color: AppColors.primary);
      case 'IN_PROGRESS':
        return (label: 'En progreso', color: AppColors.secondary);
      case 'COMPLETED':
        return (label: 'Completada', color: AppColors.success);
      case 'CANCELLED':
      case 'CANCELED':
        return (label: 'Cancelada', color: AppColors.error);
      case 'FAILED':
        return (label: 'Fallida', color: AppColors.error);
      default:
        return (label: status, color: AppColors.grey);
    }
  }

  ({String label, Color color})? _urgencyInfo(String? urgency) {
    if (urgency == null) {
      return null;
    }

    switch (urgency.toLowerCase()) {
      case 'alta':
        return (label: 'Alta', color: AppColors.error);
      case 'media':
        return (label: 'Media', color: AppColors.warning);
      case 'baja':
        return (label: 'Baja', color: AppColors.success);
      default:
        return (label: urgency, color: AppColors.grey);
    }
  }
}

class _SkillChip extends StatelessWidget {
  final String label;

  const _SkillChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
