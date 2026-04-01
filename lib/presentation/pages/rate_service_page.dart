import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/core/services/theme_service.dart';
import 'package:flutter_app/core/utils/logger.dart';

class RateServicePage extends StatefulWidget {
  final String serviceRequestId;
  final String technicianName;
  final String serviceName;
  final String tenantId;

  const RateServicePage({
    super.key,
    required this.serviceRequestId,
    required this.technicianName,
    required this.serviceName,
    required this.tenantId,
  });

  @override
  State<RateServicePage> createState() => _RateServicePageState();
}

class _RateServicePageState extends State<RateServicePage> {
  int _serviceRating = 0;
  int _technicianRating = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;
  bool _isDark = false;

  void _onThemeChanged() {
    if (mounted) setState(() => _isDark = sl<ThemeService>().isDark);
  }

  @override
  void initState() {
    super.initState();
    _isDark = sl<ThemeService>().isDark;
    sl<ThemeService>().addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _commentController.dispose();
    sl<ThemeService>().removeListener(_onThemeChanged);
    super.dispose();
  }

  Color get _bg =>
      _isDark ? const Color(0xFF0F0F0F) : AppColors.backgroundLight;
  Color get _card => _isDark ? const Color(0xFF1C1C1C) : AppColors.white;
  Color get _txtPri => _isDark ? Colors.white : AppColors.textPrimary;
  Color get _txtSec =>
      _isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;
  Color get _cardAlt =>
      _isDark ? const Color(0xFF252525) : AppColors.surfaceSoft;

  Future<void> _submit() async {
    if (_serviceRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor califica el servicio')),
      );
      return;
    }
    if (_technicianRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor califica al técnico')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final body = <String, dynamic>{
        'serviceRating': _serviceRating,
        'technicianRating': _technicianRating,
      };
      final comment = _commentController.text.trim();
      if (comment.isNotEmpty) body['comment'] = comment;

      await sl<Dio>().post(
        '/service-requests/${widget.serviceRequestId}/rate',
        data: body,
        options: widget.tenantId.isNotEmpty
            ? Options(headers: {'X-Tenant-ID': widget.tenantId})
            : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map<String, dynamic>
          ? e.response?.data['message']?.toString()
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg ?? 'No se pudo enviar la calificación')),
      );
      AppLogger.error('Error rating service: $e');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ocurrió un error inesperado')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildStarSelector({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _txtPri,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (i) {
            final star = i + 1;
            return GestureDetector(
              onTap: () => onChanged(star),
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  star <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: star <= value ? Colors.amber : _txtSec,
                  size: 36,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        title: Text(
          'Calificar servicio',
          style: TextStyle(color: _txtPri, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: _txtPri),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Técnico',
                        style: TextStyle(fontSize: 13, color: _txtSec),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.technicianName,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _txtPri,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.build_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Servicio',
                        style: TextStyle(fontSize: 13, color: _txtSec),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.serviceName,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _txtPri,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStarSelector(
                    label: 'Calificación del servicio',
                    value: _serviceRating,
                    onChanged: (v) => setState(() => _serviceRating = v),
                  ),
                  const SizedBox(height: 24),
                  _buildStarSelector(
                    label: 'Calificación del técnico',
                    value: _technicianRating,
                    onChanged: (v) => setState(() => _technicianRating = v),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Comentario (opcional)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _txtPri,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _cardAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _commentController,
                      maxLines: 4,
                      style: TextStyle(color: _txtPri),
                      decoration: InputDecoration(
                        hintText: 'Cuéntanos sobre tu experiencia...',
                        hintStyle: TextStyle(color: _txtSec),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.5),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Enviar calificación',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
