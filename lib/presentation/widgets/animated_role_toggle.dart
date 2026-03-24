import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

/// Selector Cliente / Profesional con deslizamiento y transición de color
/// entre perfil azul (cliente) y variante más cálida (profesional + acento).
class AnimatedRoleToggle extends StatefulWidget {
  const AnimatedRoleToggle({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  /// 0 = Cliente, 1 = Profesional
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  State<AnimatedRoleToggle> createState() => _AnimatedRoleToggleState();
}

class _AnimatedRoleToggleState extends State<AnimatedRoleToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static final BoxDecoration _clientDecoration = BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.primary, AppColors.primaryLight],
    ),
    borderRadius: BorderRadius.circular(14),
    boxShadow: [
      BoxShadow(
        color: AppColors.primary.withValues(alpha: 0.38),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
    ],
  );

  static final BoxDecoration _professionalDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.primaryDark,
        Color.lerp(AppColors.secondary, AppColors.primaryDark, 0.35)!,
      ],
    ),
    borderRadius: BorderRadius.circular(14),
    boxShadow: [
      BoxShadow(
        color: AppColors.secondary.withValues(alpha: 0.42),
        blurRadius: 16,
        offset: const Offset(0, 7),
      ),
    ],
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      value: widget.selectedIndex.clamp(0, 1).toDouble(),
    );
  }

  @override
  void didUpdateWidget(AnimatedRoleToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _controller.animateTo(
        widget.selectedIndex.clamp(0, 1).toDouble(),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    if (index == widget.selectedIndex) return;
    HapticFeedback.selectionClick();
    widget.onChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const outerPadding = 4.0;
        final innerW = constraints.maxWidth - outerPadding * 2;
        final segmentW = innerW / 2;

        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.greyLight.withValues(alpha: 0.85),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(outerPadding),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value;
              final pillDecoration = BoxDecoration.lerp(
                _clientDecoration,
                _professionalDecoration,
                t,
              )!;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: t * segmentW,
                    top: 0,
                    bottom: 0,
                    width: segmentW,
                    child: DecoratedBox(decoration: pillDecoration),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _Segment(
                          icon: Icons.person_outline_rounded,
                          label: 'Cliente',
                          selectedProgress: 1 - t,
                          onTap: () => _onTap(0),
                        ),
                      ),
                      Expanded(
                        child: _Segment(
                          icon: Icons.work_outline_rounded,
                          label: 'Profesional',
                          selectedProgress: t,
                          onTap: () => _onTap(1),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.selectedProgress,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  /// 1 = fully sobre la píldora, 0 = fuera; interpola colores durante el slide
  final double selectedProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onPill = selectedProgress.clamp(0.0, 1.0);
    final labelColor = Color.lerp(
      AppColors.textSecondary,
      Colors.white,
      onPill,
    )!;
    final iconColor = Color.lerp(
      AppColors.grey,
      Colors.white,
      onPill,
    )!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.primary.withValues(alpha: 0.12),
        highlightColor: AppColors.primary.withValues(alpha: 0.06),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 21, color: iconColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
