import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/core/services/theme_service.dart';

class TermsAndConditionsPage extends StatefulWidget {
  const TermsAndConditionsPage({super.key});

  @override
  State<TermsAndConditionsPage> createState() => _TermsAndConditionsPageState();
}

class _TermsAndConditionsPageState extends State<TermsAndConditionsPage> {
  bool _isDark = false;

  static const List<String> _terms = [
    'Al registrarte y usar CameYo aceptas estos Términos y Condiciones, así como la Política de Privacidad aplicable.',
    'CameYo es una plataforma digital de intermediación que conecta clientes con técnicos/profesionales para servicios bajo demanda.',
    'Debes proporcionar información real, completa y actualizada durante el registro y uso de tu cuenta.',
    'Eres responsable de mantener la confidencialidad de tus credenciales y de cualquier actividad realizada desde tu cuenta.',
    'El cliente debe describir el servicio con información veraz, incluyendo ubicación y condiciones relevantes para su ejecución.',
    'El profesional debe prestar el servicio de forma diligente, segura y respetuosa, cumpliendo las normas legales vigentes.',
    'Los pagos, cancelaciones, reprogramaciones y reclamaciones se rigen por las condiciones visibles en la app al momento de la solicitud.',
    'Está prohibido usar la plataforma para actividades ilícitas, fraudulentas, ofensivas o que pongan en riesgo a otros usuarios.',
    'CameYo puede suspender o cancelar cuentas por incumplimiento de estos términos o por uso indebido de la plataforma.',
    'CameYo podrá actualizar estos términos cuando sea necesario; el uso continuado de la app implica aceptación de la versión vigente.',
  ];

  static const List<String> _law1581 = [
    'En CameYo se tratan datos personales como nombre, correo, teléfono, dirección, ubicación y datos transaccionales del servicio.',
    'El tratamiento se realiza para finalidades de registro, autenticación, operación de la plataforma, gestión de servicios, soporte y cumplimiento legal.',
    'El titular autoriza de manera previa, expresa e informada el tratamiento de sus datos, conforme a la Ley 1581 de 2012 y el Decreto 1377 de 2013.',
    'El titular puede ejercer sus derechos de conocer, actualizar, rectificar, suprimir sus datos y revocar la autorización cuando proceda legalmente.',
    'CameYo adopta medidas razonables de seguridad administrativas, técnicas y organizativas para proteger los datos personales.',
    'La política de privacidad debe incluir: responsable del tratamiento, finalidades, derechos del titular y canales para consultas/reclamos.',
    'Cuando aplique por normatividad vigente, se evaluará y gestionará el registro de bases de datos ante la SIC.',
  ];

  Color get _bg =>
      _isDark ? const Color(0xFF0F0F0F) : AppColors.backgroundLight;
  Color get _card => _isDark ? const Color(0xFF1C1C1C) : AppColors.white;
  Color get _txtPri => _isDark ? Colors.white : AppColors.textPrimary;
  Color get _txtSec =>
      _isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;

  @override
  void initState() {
    super.initState();
    _isDark = sl<ThemeService>().isDark;
    sl<ThemeService>().addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    sl<ThemeService>().removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        _isDark = sl<ThemeService>().isDark;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Términos y Condiciones'),
        backgroundColor: _card,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: 'Términos y condiciones del sistema CameYo',
            items: _terms,
          ),
          const SizedBox(height: 12),
          _buildSection(
            title: 'Ley 1581 de 2012 (debajo de términos y condiciones)',
            items: _law1581,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<String> items}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _txtPri,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: _txtSec,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
