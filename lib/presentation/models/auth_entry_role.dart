import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';

/// Rol elegido en el flujo de entrada (antes de login o registro).
enum AuthEntryRole {
  client,
  provider,
}

extension AuthEntryRoleX on AuthEntryRole {
  String get apiValue => this == AuthEntryRole.client ? 'client' : 'provider';

  String get shortLabel =>
      this == AuthEntryRole.client ? 'Cliente' : 'Profesional';

  String get valueProposition =>
      this == AuthEntryRole.client ? 'Encuentra servicios' : 'Ofrece tus servicios';

  String get loginTitle =>
      this == AuthEntryRole.client ? '¡Hola de nuevo!' : 'Acceso profesional';

  String get loginSubtitle => valueProposition;

  String get signupTitle =>
      this == AuthEntryRole.client ? 'Crea tu cuenta' : 'Registro profesional';

  String get signupSubtitle => this == AuthEntryRole.client
      ? 'Encuentra lo que necesitas en minutos'
      : 'Gestiona solicitudes y haz crecer tu negocio';

  IconData get icon =>
      this == AuthEntryRole.client ? Icons.person_rounded : Icons.work_rounded;

  Color get accent =>
      this == AuthEntryRole.client ? AppColors.primary : AppColors.secondary;

  Color get accentDeep =>
      this == AuthEntryRole.client ? AppColors.primaryDark : AppColors.secondaryDark;

  List<Color> get heroGradientColors {
    if (this == AuthEntryRole.client) {
      return [
        AppColors.backgroundDark,
        Color.lerp(AppColors.backgroundDark, AppColors.primary, 0.35)!,
        AppColors.primary.withValues(alpha: 0.55),
        AppColors.white,
      ];
    }
    return [
      AppColors.backgroundDark,
      Color.lerp(AppColors.primaryDark, AppColors.secondary, 0.45)!,
      AppColors.secondary.withValues(alpha: 0.5),
      AppColors.white,
    ];
  }

  List<String> get benefits {
    if (this == AuthEntryRole.client) {
      return const [
        'Explora servicios cerca de ti',
        'Reserva y paga con confianza',
        'Historial claro de tus pedidos',
      ];
    }
    return const [
      'Recibe solicitudes al instante',
      'Controla tu disponibilidad y precios',
      'Cobra y crece con CameYo',
    ];
  }
}
