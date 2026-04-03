import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/core/utils/logger.dart';
import 'package:flutter_app/core/utils/name_utils.dart';
import 'package:flutter_app/domain/entities/service_request.dart';
import 'package:intl/intl.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';

class ServiceSummaryModal extends StatelessWidget {
  final ServiceRequest serviceRequest;
  final String tenantId;

  const ServiceSummaryModal({
    super.key,
    required this.serviceRequest,
    required this.tenantId,
  });

  static Future<void> show(
    BuildContext context, {
    required ServiceRequest serviceRequest,
    required String tenantId,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => ServiceSummaryModal(
        serviceRequest: serviceRequest,
        tenantId: tenantId,
      ),
    );
  }

  String _formatDuration(ServiceRequest req) {
    if (req.startedAt == null || req.completedAt == null) return 'N/A';
    final diff = req.completedAt!.difference(req.startedAt!);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}min';
    return '${minutes}min';
  }

  String _formatPrice(double? price) {
    if (price == null) return 'Por definir';
    final formatter = NumberFormat('#,###', 'es_CO');
    return '\$${formatter.format(price.toInt())}';
  }

  /// Converts a UTC DateTime to Colombia time (UTC-5) before formatting.
  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    final colombiaTime = date.toUtc().subtract(const Duration(hours: 5));
    return DateFormat("d MMM yyyy, h:mm a", 'es').format(colombiaTime);
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '??';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  String _capitalizeFirst(String? text) {
    if (text == null || text.isEmpty) return 'N/A';
    return text[0].toUpperCase() + text.substring(1);
  }

  Future<void> _downloadReceipt(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Descargando recibo...')),
      );

      // Get the blob URL from the backend
      final response = await sl<Dio>().get(
        '/service-requests/${serviceRequest.id}/receipt',
        options: tenantId.isNotEmpty
            ? Options(headers: {'X-Tenant-ID': tenantId})
            : null,
      );
      final url = response.data['url'] as String;

      // Download to a temp file first, then move to public Downloads
      // via MediaStore (works on Android 10, 11, 12, 13, 14+).
      final fileName = 'recibo_${serviceRequest.id.substring(0, 8)}.pdf';
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$fileName';
      await Dio().download(url, tempPath);

      await MediaStore().saveFile(
        tempFilePath: tempPath,
        dirType: DirType.download,
        dirName: DirName.download,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recibo guardado: $fileName')),
      );
    } catch (e) {
      AppLogger.error('Error downloading receipt: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al descargar el recibo')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = serviceRequest;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1C1C1C) : Colors.white;
    final onSurface = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final secondaryText = isDark
        ? const Color(0xFF9E9E9E)
        : const Color(0xFF757575);
    final borderColor = (isDark ? Colors.white : Colors.black)
        .withValues(alpha: 0.08);

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.info,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Servicio completado',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(req.completedAt),
                  style: TextStyle(fontSize: 13, color: secondaryText),
                ),
                const SizedBox(height: 16),

                // Technician section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: borderColor, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Profile photo or initials avatar
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        backgroundImage:
                            req.technicianPhotoUrl != null &&
                                    req.technicianPhotoUrl!.isNotEmpty
                                ? NetworkImage(req.technicianPhotoUrl!)
                                : null,
                        child: req.technicianPhotoUrl == null ||
                                req.technicianPhotoUrl!.isEmpty
                            ? Text(
                                _getInitials(req.technicianName),
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shortName(req.technicianName),
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tecnico asignado',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Service details section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: borderColor, width: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRowText(
                        onSurface,
                        secondaryText,
                        'Categoria',
                        _capitalizeFirst(req.categoryName),
                      ),
                      const SizedBox(height: 6),
                      _buildDetailRowText(
                        onSurface,
                        secondaryText,
                        'Urgencia',
                        _capitalizeFirst(req.urgency),
                      ),
                      const SizedBox(height: 6),
                      _buildDetailRowText(
                        onSurface,
                        secondaryText,
                        'Duracion',
                        _formatDuration(req),
                      ),
                      const SizedBox(height: 6),
                      _buildDetailRowText(
                        onSurface,
                        secondaryText,
                        'Distancia',
                        '${req.displacementDistanceKm ?? 0} km',
                      ),
                    ],
                  ),
                ),

                // Total section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: onSurface,
                        ),
                      ),
                      Text(
                        _formatPrice(req.finalPrice),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info.withValues(alpha: 0.15),
                      foregroundColor: AppColors.info,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Pagar ahora',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => _downloadReceipt(context),
                    child: Text(
                      'Descargar recibo',
                      style: TextStyle(fontSize: 13, color: secondaryText),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRowText(
    Color onSurface,
    Color secondaryText,
    String label,
    String value,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: secondaryText),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: onSurface,
          ),
        ),
      ],
    );
  }
}
