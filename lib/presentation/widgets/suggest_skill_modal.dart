import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/presentation/bloc/skill_suggestion/skill_suggestion_bloc.dart';
import 'package:flutter_app/presentation/bloc/skill_suggestion/skill_suggestion_event.dart';
import 'package:flutter_app/presentation/bloc/skill_suggestion/skill_suggestion_state.dart';
import 'package:google_fonts/google_fonts.dart';

class SuggestSkillModal extends StatefulWidget {
  const SuggestSkillModal({super.key});

  @override
  State<SuggestSkillModal> createState() => _SuggestSkillModalState();
}

class _SuggestSkillModalState extends State<SuggestSkillModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<SkillSuggestionBloc>().add(
            SubmitSkillSuggestionEvent(
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim(),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    final dragHandleColor =
        isDark ? Colors.grey.shade600 : Colors.grey.shade300;
    final titleColor = isDark ? Colors.white : AppColors.textPrimary;
    final subtitleColor =
        isDark ? Colors.grey.shade400 : AppColors.textSecondary;
    final labelColor = isDark ? Colors.white : AppColors.textPrimary;
    final inputFillColor =
        isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50;
    final inputBorderColor =
        isDark ? Colors.grey.shade700 : Colors.grey.shade200;
    final inputTextColor = isDark ? Colors.white : AppColors.textPrimary;
    final hintColor = isDark
        ? Colors.grey.shade500
        : AppColors.textHint.withValues(alpha: 0.5);

    return BlocConsumer<SkillSuggestionBloc, SkillSuggestionState>(
      listener: (context, state) {
        if (state is SkillSuggestionSuccess) {
          final messenger = ScaffoldMessenger.of(context);
          final nav = Navigator.of(context);
          nav.pop();
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                '¡Sugerencia enviada con éxito!',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state is SkillSuggestionFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.message,
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is SkillSuggestionLoading;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: dragHandleColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Sugerir habilidad',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Propón una nueva habilidad para agregar al catálogo.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Nombre de la habilidad',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    enabled: !isLoading,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: inputTextColor,
                    ),
                    decoration: _inputDecoration(
                      'Ej: Carpintería, Plomería...',
                      hintColor: hintColor,
                      fillColor: inputFillColor,
                      borderColor: inputBorderColor,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El nombre es obligatorio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Descripción',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    enabled: !isLoading,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: inputTextColor,
                    ),
                    decoration: _inputDecoration(
                      'Describe brevemente en qué consiste esta habilidad...',
                      hintColor: hintColor,
                      fillColor: inputFillColor,
                      borderColor: inputBorderColor,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'La descripción es obligatoria';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Enviar sugerencia',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(
    String hint, {
    required Color hintColor,
    required Color fillColor,
    required Color borderColor,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: hintColor),
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
