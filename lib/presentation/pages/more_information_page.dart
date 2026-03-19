import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/core/services/theme_service.dart';
import 'package:flutter_app/presentation/pages/terms_and_conditions_page.dart';

class MoreInformationPage extends StatefulWidget {
  const MoreInformationPage({super.key});

  @override
  State<MoreInformationPage> createState() => _MoreInformationPageState();
}

class _MoreInformationPageState extends State<MoreInformationPage> {
  bool _isDark = false;

  Color get _bg =>
      _isDark ? const Color(0xFF0F0F0F) : AppColors.backgroundLight;
  Color get _card => _isDark ? const Color(0xFF1C1C1C) : AppColors.white;
  Color get _divider => _isDark ? const Color(0xFF2E2E2E) : AppColors.greyLight;
  Color get _txtPri => _isDark ? Colors.white : AppColors.textPrimary;

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
        backgroundColor: _card,
        elevation: 0,
        title: Text(
          'Más información',
          style: TextStyle(color: _txtPri, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _MoreInfoItem(
                  icon: Icons.storefront_outlined,
                  title: 'Quiero ser Aliado CameYo',
                  isDark: _isDark,
                  onTap: () => _openDetail(
                    context,
                    title: 'Quiero ser Aliado CameYo',
                    sections: const [
                      'Puedes postularte como profesional aliado para ofrecer servicios dentro de la plataforma CameYo.',
                      'Debes completar tu perfil con datos reales, habilidades, experiencia y disponibilidad.',
                      'La activación puede requerir validación de identidad y verificación de información.',
                      'Una vez aprobado, podrás recibir y aceptar solicitudes de clientes en tiempo real.',
                    ],
                  ),
                ),
                _ItemDivider(color: _divider),
                _MoreInfoItem(
                  icon: Icons.info_outline,
                  title: 'Términos y Condiciones',
                  isDark: _isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TermsAndConditionsPage(),
                      ),
                    );
                  },
                ),
                _ItemDivider(color: _divider),
                _MoreInfoItem(
                  icon: Icons.verified_user_outlined,
                  title: 'Política de Privacidad',
                  isDark: _isDark,
                  onTap: () => _openDetail(
                    context,
                    title: 'Política de Privacidad',
                    sections: const [
                      'CameYo trata datos personales para operar el servicio, autenticar usuarios, gestionar solicitudes y brindar soporte.',
                      'Solo se recopilan los datos necesarios para la finalidad informada al titular.',
                      'Se aplican medidas técnicas y organizativas para proteger confidencialidad, integridad y disponibilidad de la información.',
                      'El titular puede ejercer sus derechos mediante los canales oficiales definidos por la plataforma.',
                    ],
                  ),
                ),
                _ItemDivider(color: _divider),
                _MoreInfoItem(
                  icon: Icons.info_outline,
                  title: 'Información relevante',
                  isDark: _isDark,
                  onTap: () => _openDetail(
                    context,
                    title: 'Información relevante',
                    sections: const [
                      'CameYo actúa como plataforma intermediaria entre clientes y profesionales independientes.',
                      'Los tiempos, disponibilidad y resultados del servicio pueden variar según la zona y oferta activa.',
                      'Las tarifas y condiciones aplicables se muestran en la app y pueden cambiar según el tipo de servicio.',
                      'Para reportes o solicitudes especiales, utiliza los canales de soporte de la aplicación.',
                    ],
                  ),
                ),
                _ItemDivider(color: _divider),
                _MoreInfoItem(
                  icon: Icons.shield_outlined,
                  title: 'Autorización de tratamiento de datos personales',
                  isDark: _isDark,
                  onTap: () => _openDetail(
                    context,
                    title: 'Autorización de tratamiento de datos personales',
                    sections: const [
                      'Con el registro y uso de CameYo autorizas de forma previa, expresa e informada el tratamiento de tus datos personales.',
                      'La autorización se usa para finalidades operativas, de seguridad, cumplimiento legal y mejora del servicio.',
                      'Puedes revocar la autorización o solicitar supresión de datos cuando legalmente proceda.',
                      'El tratamiento se realiza conforme a la Ley 1581 de 2012 y el Decreto 1377 de 2013.',
                    ],
                  ),
                ),
                _ItemDivider(color: _divider),
                _MoreInfoItem(
                  icon: Icons.account_balance_outlined,
                  title: 'Superintendencia de Industria y Comercio',
                  isDark: _isDark,
                  onTap: () => _openDetail(
                    context,
                    title: 'Superintendencia de Industria y Comercio',
                    sections: const [
                      'La SIC es la autoridad nacional en Colombia para la protección de datos personales.',
                      'Si consideras vulnerados tus derechos y no recibes respuesta adecuada, puedes acudir a la SIC.',
                      'Consulta información oficial en www.sic.gov.co.',
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(
    BuildContext context, {
    required String title,
    required List<String> sections,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _InformationDetailPage(title: title, sections: sections),
      ),
    );
  }
}

class _InformationDetailPage extends StatelessWidget {
  final String title;
  final List<String> sections;

  const _InformationDetailPage({required this.title, required this.sections});

  @override
  Widget build(BuildContext context) {
    final isDark = sl<ThemeService>().isDark;
    final bg = isDark ? const Color(0xFF0F0F0F) : AppColors.backgroundLight;
    final card = isDark ? const Color(0xFF1C1C1C) : AppColors.white;
    final txtPri = isDark ? Colors.white : AppColors.textPrimary;
    final txtSec = isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        title: Text(title, style: TextStyle(color: txtPri)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sections
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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
                                color: txtSec,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreInfoItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDark;
  final VoidCallback onTap;

  const _MoreInfoItem({
    required this.icon,
    required this.title,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = AppColors.primary;
    final txtColor = isDark ? Colors.white : AppColors.textPrimary;
    final chevronColor = isDark ? const Color(0xFF9E9E9E) : AppColors.grey;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: txtColor,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: chevronColor, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ItemDivider extends StatelessWidget {
  final Color color;

  const _ItemDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child: Divider(height: 1, thickness: 1, color: color),
    );
  }
}
