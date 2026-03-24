import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_bloc.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_event.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_state.dart';
import 'package:flutter_app/presentation/models/auth_entry_role.dart';
import 'package:flutter_app/presentation/widgets/google_auth_button.dart';
import 'package:flutter_app/presentation/widgets/primary_button.dart';
import 'package:flutter_app/presentation/widgets/custom_text_field.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key, required this.selectedRole});

  final AuthEntryRole selectedRole;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;

  String get _selectedRole => widget.selectedRole.apiValue;

  /// Alineado con la validación del backend Nest (mayúscula, minúscula, número, @$!%*?&).
  String? _validatePasswordPolicy(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu contraseña';
    }
    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    final hasLower = RegExp('[a-z]').hasMatch(value);
    final hasUpper = RegExp('[A-Z]').hasMatch(value);
    final hasDigit = RegExp('[0-9]').hasMatch(value);
    final hasSpecial = RegExp(r'[@$!%*?&]').hasMatch(value);
    if (!hasLower || !hasUpper || !hasDigit || !hasSpecial) {
      return 'Incluye mayúscula, minúscula, número y un símbolo (@\$!%*?&)';
    }
    return null;
  }

  static const List<String> _termsItems = [
    'Aceptas los términos y condiciones de uso de CameYo para crear una cuenta.',
    'Autorizas el tratamiento de datos personales de acuerdo con la Ley 1581 de 2012 y el Decreto 1377 de 2013.',
    'Tus datos se usan para gestionar registro, autenticación, solicitudes de servicio y soporte de la plataforma.',
    'Puedes ejercer derechos de acceso, actualización, rectificación y supresión de datos cuando aplique.',
    'Para continuar con el registro debes otorgar aceptación expresa de estos términos.',
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSignUp() {
    if (!_acceptedTerms) {
      _showTermsRequiredMessage();
      return;
    }

    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
        SignUpEvent(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          role: _selectedRole,
          phoneNumber: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
        ),
      );
    }
  }

  void _handleGoogleSignUp() {
    if (!_acceptedTerms) {
      _showTermsRequiredMessage();
      return;
    }

    context.read<AuthBloc>().add(
      LoginWithGoogleEvent(selectedRole: _selectedRole),
    );
  }

  void _showTermsRequiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Debes aceptar los términos y condiciones para continuar.',
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Términos y condiciones'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _termsItems
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text('• $item'),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          } else if (state is SignUpSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('¡Registro exitoso! Bienvenido'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
            // Navigate based on role
            if (state.user.isClient) {
              Navigator.pushReplacementNamed(context, '/client-home');
            } else if (state.user.isProvider) {
              Navigator.pushReplacementNamed(context, '/provider-home');
            }
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return Container(
            width: size.width,
            height: size.height,
            color: AppColors.backgroundLight,
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeInDown(
                      duration: const Duration(milliseconds: 520),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: widget.selectedRole.heroGradientColors,
                                stops: const [0.0, 0.38, 0.72, 1.0],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(36),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.backgroundDark.withValues(
                                    alpha: 0.22,
                                  ),
                                  blurRadius: 28,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.fromLTRB(24, 44, 24, 44),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.selectedRole.signupTitle,
                                  style: GoogleFonts.poppins(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.white,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.selectedRole.valueProposition,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.white.withValues(
                                      alpha: 0.95,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.selectedRole.signupSubtitle,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: AppColors.white.withValues(
                                      alpha: 0.86,
                                    ),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 0,
                            left: 4,
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: AppColors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -28),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding:
                              const EdgeInsets.fromLTRB(22, 28, 22, 28),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: AppColors.greyLight.withValues(
                                alpha: 0.65,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.07,
                                ),
                                blurRadius: 36,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FadeInUp(
                                  delay: const Duration(milliseconds: 200),
                                  child: _buildRoleBenefits(),
                                ),
                                FadeInUp(
                                  delay: const Duration(milliseconds: 260),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.popUntil(
                                          context,
                                          (route) =>
                                              route.settings.name ==
                                              '/auth-role',
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 0),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Elegir otro tipo de cuenta',
                                        style: GoogleFonts.poppins(
                                          color: widget.selectedRole.accent,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                  FadeInUp(
                                    delay: const Duration(milliseconds: 300),
                                    child: _buildFieldLabel('Nombre Completo'),
                                  ),
                                  FadeInUp(
                                    delay: const Duration(milliseconds: 300),
                                    child: CustomTextField(
                                      controller: _fullNameController,
                                      hintText: 'Juan Pérez',
                                      prefixIcon: Icons.person_outline,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Por favor ingresa tu nombre completo';
                                        }
                                        if (value.length < 2) {
                                          return 'El nombre debe tener al menos 2 caracteres';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  FadeInUp(
                                    delay: const Duration(milliseconds: 400),
                                    child: _buildFieldLabel(
                                      'Correo Electrónico',
                                    ),
                                  ),
                                  FadeInUp(
                                    delay: const Duration(milliseconds: 400),
                                    child: CustomTextField(
                                      controller: _emailController,
                                      hintText: 'tu@email.com',
                                      keyboardType: TextInputType.emailAddress,
                                      prefixIcon: Icons.email_outlined,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Por favor ingresa tu correo';
                                        }
                                        if (!value.contains('@')) {
                                          return 'Por favor ingresa un correo válido';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  FadeInUp(
                                    delay: const Duration(milliseconds: 500),
                                    child: _buildFieldLabel(
                                      'Teléfono (Opcional)',
                                    ),
                                  ),
                                  FadeInUp(
                                    delay: const Duration(milliseconds: 500),
                                    child: CustomTextField(
                                      controller: _phoneController,
                                      hintText: '+573001234567',
                                      keyboardType: TextInputType.phone,
                                      prefixIcon: Icons.phone_outlined,
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  FadeInUp(
                                    delay: const Duration(milliseconds: 600),
                                    child: _buildFieldLabel('Contraseña'),
                                  ),
                                  FadeInUp(
                                    delay: const Duration(milliseconds: 600),
                                    child: CustomTextField(
                                      controller: _passwordController,
                                      hintText: '••••••••',
                                      obscureText: _obscurePassword,
                                      prefixIcon: Icons.lock_outlined,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: AppColors.grey,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          });
                                        },
                                      ),
                                      validator: _validatePasswordPolicy,
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  FadeInUp(
                                    delay: const Duration(milliseconds: 700),
                                    child: _buildFieldLabel(
                                      'Confirmar Contraseña',
                                    ),
                                  ),
                                  FadeInUp(
                                    delay: const Duration(milliseconds: 700),
                                    child: CustomTextField(
                                      controller: _confirmPasswordController,
                                      hintText: '••••••••',
                                      obscureText: _obscureConfirmPassword,
                                      prefixIcon: Icons.lock_outlined,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureConfirmPassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: AppColors.grey,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscureConfirmPassword =
                                                !_obscureConfirmPassword;
                                          });
                                        },
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Por favor confirma tu contraseña';
                                        }
                                        if (value != _passwordController.text) {
                                          return 'Las contraseñas no coinciden';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),

                                  const SizedBox(height: 32),

                                  FadeInUp(
                                    delay: const Duration(milliseconds: 780),
                                    child: _buildTermsAcceptance(),
                                  ),

                                  const SizedBox(height: 16),

                                  // Sign Up Button
                                  FadeInUp(
                                    delay: const Duration(milliseconds: 800),
                                    child: PrimaryButton(
                                      text: 'Registrarse',
                                      onPressed: isLoading
                                          ? null
                                          : _handleSignUp,
                                      isLoading: isLoading,
                                      backgroundColor:
                                          widget.selectedRole.accent,
                                    ),
                                  ),

                                  const SizedBox(height: 32),

                                  // Divider
                                  FadeInUp(
                                    delay: const Duration(milliseconds: 900),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            height: 1,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.transparent,
                                                  AppColors.greyLight,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          child: Text(
                                            'O REGÍSTRATE CON',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: AppColors.grey,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            height: 1,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  AppColors.greyLight,
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Google Sign Up Button
                                  FadeInUp(
                                    delay: const Duration(milliseconds: 1000),
                                    child: _buildGoogleButton(isLoading),
                                  ),

                                  const SizedBox(height: 32),

                                  // Login Link
                                  FadeInUp(
                                    delay: const Duration(milliseconds: 1100),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '¿Ya tienes cuenta? ',
                                          style: GoogleFonts.poppins(
                                            color: AppColors.textSecondary,
                                            fontSize: 14,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(0, 0),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: Text(
                                            'Inicia Sesión',
                                            style: GoogleFonts.poppins(
                                              color: widget.selectedRole.accent,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoleBenefits() {
    final accent = widget.selectedRole.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tu perfil: ${widget.selectedRole.shortLabel}',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 12),
        ...widget.selectedRole.benefits.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 20,
                  color: accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    line,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildGoogleButton(bool isLoading) {
    return GoogleAuthButton(
      onPressed: isLoading ? null : _handleGoogleSignUp,
      isLoading: isLoading,
    );
  }

  Widget _buildTermsAcceptance() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
        border: Border.all(color: AppColors.greyLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _acceptedTerms,
            activeColor: widget.selectedRole.accent,
            onChanged: (value) {
              setState(() {
                _acceptedTerms = value ?? false;
              });
            },
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                children: [
                  Text(
                    'Acepto los ',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: _showTermsDialog,
                    child: Text(
                      'términos y condiciones',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: widget.selectedRole.accent,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  Text(
                    ' para completar el registro.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textSecondary,
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
