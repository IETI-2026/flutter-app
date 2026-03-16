import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_bloc.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Paleta premium negro + naranja (misma que provider_home_page) ────────────
const _bg      = Color(0xFF0F0F0F);
const _card    = Color(0xFF1C1C1C);
const _cardAlt = Color(0xFF252525);
const _border  = Color(0xFF2E2E2E);
const _txtPri  = Colors.white;
const _txtSec  = Color(0xFF9E9E9E);
const _txtHint = Color(0xFF5A5A5A);
const _orange  = AppColors.primary;
// ─────────────────────────────────────────────────────────────────────────────

class ProviderOnboardingPage extends StatefulWidget {
  const ProviderOnboardingPage({super.key});

  @override
  State<ProviderOnboardingPage> createState() => _ProviderOnboardingPageState();
}

class _ProviderOnboardingPageState extends State<ProviderOnboardingPage> {
  static const _allSkills = [
    'plomeria', 'electricidad', 'cerrajeria', 'gas', 'albanileria',
    'carpinteria', 'refrigeracion', 'tecnologia', 'jardineria', 'pintura',
    'limpieza', 'impermeabilizacion', 'techos', 'vidrieria', 'soldadura',
    'mantenimiento', 'mascotas', 'mudanza', 'otro',
  ];

  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final _coverageController = TextEditingController(text: '15');
  final _nequiController = TextEditingController();
  final _daviplataController = TextEditingController();
  final _skillSearchController = TextEditingController();

  final List<String> _selectedSkills = [];
  List<String> _filteredSkills = _allSkills;
  bool _isAvailable = true;
  bool _isLoading = false;
  bool _showSkillDropdown = false;

  @override
  void dispose() {
    _bioController.dispose();
    _coverageController.dispose();
    _nequiController.dispose();
    _daviplataController.dispose();
    _skillSearchController.dispose();
    super.dispose();
  }

  List<String> _filterSkills(String query) {
    final q = query.toLowerCase().trim();
    return _allSkills
        .where((s) => !_selectedSkills.contains(s) && s.contains(q))
        .toList();
  }

  void _onSkillSearchChanged(String query) {
    setState(() {
      _filteredSkills = _filterSkills(query);
      _showSkillDropdown = true;
    });
  }

  void _selectSkill(String skill) {
    setState(() {
      _selectedSkills.add(skill);
      _skillSearchController.clear();
      _filteredSkills = _filterSkills('');
      _showSkillDropdown = false;
    });
  }

  void _removeSkill(String skill) => setState(() => _selectedSkills.remove(skill));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Agrega al menos una habilidad', style: GoogleFonts.poppins(color: _txtPri)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final body = <String, dynamic>{
        'bio': _bioController.text.trim(),
        'coverageRadiusKm': int.tryParse(_coverageController.text.trim()) ?? 15,
        'isAvailable': _isAvailable,
        'skills': _selectedSkills,
      };
      if (_nequiController.text.trim().isNotEmpty) {
        body['nequiNumber'] = _nequiController.text.trim();
      }
      if (_daviplataController.text.trim().isNotEmpty) {
        body['daviplataNumber'] = _daviplataController.text.trim();
      }

      await sl<Dio>().post('/users/me/provider-profile', data: body);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/provider-home');
    } on DioException catch (e) {
      if (!mounted) return;
      final raw = e.response?.data;
      final message = raw is Map<String, dynamic>
          ? (raw['message'] is List
              ? (raw['message'] as List).join(' ')
              : raw['message']?.toString() ?? 'Error al crear el perfil')
          : 'Error al crear el perfil';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final firstName = state is Authenticated
            ? state.user.fullName.split(' ').first
            : '';

        return Scaffold(
          backgroundColor: _bg,
          body: GestureDetector(
            onTap: () => setState(() => _showSkillDropdown = false),
            behavior: HitTestBehavior.translucent,
            child: Column(
              children: [
                _buildHeader(firstName),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Descripción profesional'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _bioController,
                            maxLines: 3,
                            style: GoogleFonts.poppins(fontSize: 14, color: _txtPri),
                            inputFormatters: [_LowerCaseFormatter()],
                            decoration: _inputDecoration(
                              'ej: electricista con 5 años de experiencia...',
                              Icons.description_outlined,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ingresa una descripción'
                                : null,
                          ),

                          const SizedBox(height: 20),
                          _buildLabel('Radio de cobertura (km)'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _coverageController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: GoogleFonts.poppins(fontSize: 14, color: _txtPri),
                            decoration: _inputDecoration('ej: 15', Icons.my_location_outlined),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Ingresa el radio';
                              final n = int.tryParse(v.trim());
                              if (n == null || n <= 0) return 'Número inválido';
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),
                          _buildLabel('Habilidades / Especialidades'),
                          const SizedBox(height: 8),
                          _buildSkillsSelector(),
                          if (_selectedSkills.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _selectedSkills.map((s) => Chip(
                                label: Text(
                                  s,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12, color: _orange, fontWeight: FontWeight.w500,
                                  ),
                                ),
                                backgroundColor: _orange.withValues(alpha: 0.12),
                                side: BorderSide(color: _orange.withValues(alpha: 0.35)),
                                deleteIconColor: _orange,
                                onDeleted: () => _removeSkill(s),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              )).toList(),
                            ),
                          ],

                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Disponible ahora',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14, fontWeight: FontWeight.w600, color: _txtPri,
                                  ),
                                ),
                                Switch(
                                  value: _isAvailable,
                                  onChanged: (v) => setState(() => _isAvailable = v),
                                  activeTrackColor: _orange,
                                  activeThumbColor: Colors.white,
                                  inactiveTrackColor: _border,
                                  inactiveThumbColor: _txtSec,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                          _buildLabel('Nequi (opcional)'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nequiController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: GoogleFonts.poppins(fontSize: 14, color: _txtPri),
                            decoration: _inputDecoration('ej: 3001234567', Icons.account_balance_wallet_outlined),
                          ),

                          const SizedBox(height: 20),
                          _buildLabel('Daviplata (opcional)'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _daviplataController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: GoogleFonts.poppins(fontSize: 14, color: _txtPri),
                            decoration: _inputDecoration('ej: 3001234567', Icons.account_balance_outlined),
                          ),

                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _orange,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _orange.withValues(alpha: 0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24, height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : Text(
                                      'Crear perfil y comenzar',
                                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkillsSelector() {
    final available = _filteredSkills.where((s) => !_selectedSkills.contains(s)).toList();
    final showList = _showSkillDropdown && available.isNotEmpty;

    return Column(
      children: [
        TextFormField(
          controller: _skillSearchController,
          style: GoogleFonts.poppins(fontSize: 14, color: _txtPri),
          onChanged: _onSkillSearchChanged,
          onTap: () {
            setState(() {
              _filteredSkills = _filterSkills(_skillSearchController.text);
              _showSkillDropdown = true;
            });
          },
          decoration: _inputDecoration('Buscar habilidad...', Icons.search).copyWith(
            suffixIcon: _skillSearchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: _txtSec),
                    onPressed: () {
                      _skillSearchController.clear();
                      setState(() {
                        _filteredSkills = _filterSkills('');
                        _showSkillDropdown = false;
                      });
                    },
                  )
                : const Icon(Icons.keyboard_arrow_down, color: _txtSec),
          ),
        ),
        if (showList)
          Container(
            constraints: BoxConstraints(maxHeight: min(available.length * 48.0, 200)),
            decoration: BoxDecoration(
              color: _cardAlt,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: available.length,
              itemBuilder: (context, i) {
                final skill = available[i];
                final query = _skillSearchController.text.toLowerCase();
                return InkWell(
                  onTap: () => _selectSkill(skill),
                  splashColor: _orange.withValues(alpha: 0.08),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: i < available.length - 1
                          ? const Border(bottom: BorderSide(color: _border, width: 0.5))
                          : null,
                    ),
                    alignment: Alignment.centerLeft,
                    child: _buildHighlightedText(skill, query),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildHighlightedText(String skill, String query) {
    if (query.isEmpty) {
      return Text(skill, style: GoogleFonts.poppins(fontSize: 14, color: _txtPri));
    }
    final idx = skill.indexOf(query);
    if (idx == -1) {
      return Text(skill, style: GoogleFonts.poppins(fontSize: 14, color: _txtPri));
    }
    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(fontSize: 14, color: _txtSec),
        children: [
          if (idx > 0) TextSpan(text: skill.substring(0, idx)),
          TextSpan(
            text: skill.substring(idx, idx + query.length),
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: _orange),
          ),
          if (idx + query.length < skill.length)
            TextSpan(text: skill.substring(idx + query.length)),
        ],
      ),
    );
  }

  Widget _buildHeader(String firstName) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _orange.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, size: 13, color: _orange),
                    const SizedBox(width: 6),
                    Text(
                      'MODO PROFESIONAL',
                      style: GoogleFonts.poppins(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: _orange, letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                firstName.isNotEmpty ? '¡Hola, $firstName!' : '¡Bienvenido!',
                style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: _txtPri),
              ),
              const SizedBox(height: 6),
              Text(
                'Completa tu perfil para\nrecibir solicitudes de servicio.',
                style: GoogleFonts.poppins(fontSize: 14, color: _txtSec, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: _txtPri),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: _txtHint),
      prefixIcon: Icon(icon, color: _txtSec, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _orange, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      errorStyle: GoogleFonts.poppins(fontSize: 12, color: AppColors.error),
      filled: true,
      fillColor: _card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

class _LowerCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(
      text: newValue.text.toLowerCase(),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
