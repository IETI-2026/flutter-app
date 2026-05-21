import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/di/injection_container.dart';
import 'package:flutter_app/core/services/theme_service.dart';
import 'package:flutter_app/core/utils/logger.dart';
import 'package:flutter_app/presentation/widgets/profile_photo_widget.dart';

class ProviderSearchPage extends StatefulWidget {
  final String initialQuery;

  const ProviderSearchPage({super.key, this.initialQuery = ''});

  @override
  State<ProviderSearchPage> createState() => _ProviderSearchPageState();
}

class _ProviderSearchPageState extends State<ProviderSearchPage> {
  late final TextEditingController _searchController;
  List<_ProviderResult>? _results;
  bool _loading = false;
  String? _error;
  bool _isDark = false;

  Color get _bg => _isDark ? const Color(0xFF0F0F0F) : AppColors.backgroundLight;
  Color get _card => _isDark ? const Color(0xFF1C1C1C) : AppColors.white;
  Color get _cardAlt => _isDark ? const Color(0xFF252525) : AppColors.surfaceSoft;
  Color get _txtPri => _isDark ? Colors.white : AppColors.textPrimary;
  Color get _txtSec => _isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;

  void _onThemeChanged() {
    if (mounted) setState(() => _isDark = sl<ThemeService>().isDark);
  }

  @override
  void initState() {
    super.initState();
    _isDark = sl<ThemeService>().isDark;
    sl<ThemeService>().addListener(_onThemeChanged);
    _searchController = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search(widget.initialQuery));
    }
  }

  @override
  void dispose() {
    sl<ThemeService>().removeListener(_onThemeChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await sl<Dio>().get(
        '/users/providers/search',
        queryParameters: {'skill': trimmed},
      );

      final list = (response.data as List<dynamic>? ?? []);
      setState(() {
        _results = list
            .whereType<Map<String, dynamic>>()
            .map(_ProviderResult.fromJson)
            .toList();
        _loading = false;
      });
    } catch (e) {
      AppLogger.error('Error searching providers: $e');
      setState(() {
        _error = 'No se pudieron cargar los resultados. Intenta de nuevo.';
        _loading = false;
      });
    }
  }

  void _showComingSoon() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Chat'),
        content: const Text('Próximamente disponible'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        foregroundColor: _txtPri,
        elevation: 0,
        title: Text(
          'Buscar camellos',
          style: TextStyle(color: _txtPri, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: _txtPri),
      ),
      body: Column(
        children: [
          Container(
            color: _card,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _cardAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: widget.initialQuery.isEmpty,
                textInputAction: TextInputAction.search,
                onSubmitted: _search,
                style: TextStyle(color: _txtPri),
                decoration: InputDecoration(
                  hintText: 'Ej: plomería, electricidad...',
                  hintStyle: TextStyle(color: _txtSec),
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: _txtSec),
                ),
              ),
            ),
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
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: _txtSec),
          ),
        ),
      );
    }

    if (_results == null) {
      return Center(
        child: Text(
          'Escribe una habilidad para buscar prestadores',
          style: TextStyle(color: _txtSec),
        ),
      );
    }

    if (_results!.isEmpty) {
      return Center(
        child: Text(
          'No se encontraron prestadores con esa habilidad',
          style: TextStyle(color: _txtSec),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _results!.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _ProviderCard(
        provider: _results![index],
        card: _card,
        cardAlt: _cardAlt,
        txtPri: _txtPri,
        txtSec: _txtSec,
        onChat: _showComingSoon,
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final _ProviderResult provider;
  final Color card;
  final Color cardAlt;
  final Color txtPri;
  final Color txtSec;
  final VoidCallback onChat;

  const _ProviderCard({
    required this.provider,
    required this.card,
    required this.cardAlt,
    required this.txtPri,
    required this.txtSec,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfilePhotoWidget(
                  photoUrl: provider.profilePhotoUrl,
                  name: provider.fullName,
                  radius: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              provider.fullName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: txtPri,
                              ),
                            ),
                          ),
                          if (provider.isAvailable)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Disponible',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (provider.averageRating != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              '${provider.averageRating!.toStringAsFixed(1)} (${provider.totalRatings})',
                              style: TextStyle(fontSize: 13, color: txtSec),
                            ),
                          ],
                        ),
                      ],
                      if (provider.bio != null && provider.bio!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          provider.bio!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: txtSec),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (provider.skills.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: provider.skills
                    .take(4)
                    .map(
                      (skill) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cardAlt,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          skill,
                          style: TextStyle(fontSize: 12, color: txtPri),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onChat,
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('Chatear'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderResult {
  final String userId;
  final String fullName;
  final String? profilePhotoUrl;
  final String? bio;
  final List<String> skills;
  final double? averageRating;
  final int totalRatings;
  final bool isAvailable;
  final String verificationStatus;

  const _ProviderResult({
    required this.userId,
    required this.fullName,
    this.profilePhotoUrl,
    this.bio,
    required this.skills,
    this.averageRating,
    required this.totalRatings,
    required this.isAvailable,
    required this.verificationStatus,
  });

  factory _ProviderResult.fromJson(Map<String, dynamic> json) {
    return _ProviderResult(
      userId: json['userId']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      profilePhotoUrl: json['profilePhotoUrl']?.toString(),
      bio: json['bio']?.toString(),
      skills: (json['skills'] as List<dynamic>? ?? []).map((s) => s.toString()).toList(),
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      totalRatings: (json['totalRatings'] as num?)?.toInt() ?? 0,
      isAvailable: json['isAvailable'] as bool? ?? false,
      verificationStatus: json['verificationStatus']?.toString() ?? '',
    );
  }
}
