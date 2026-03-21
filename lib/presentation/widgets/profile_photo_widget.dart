import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/app_colors.dart';
import 'package:flutter_app/core/utils/logger.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_bloc.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_event.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePhotoWidget extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;

  const ProfilePhotoWidget({
    super.key,
    required this.photoUrl,
    required this.name,
    this.radius = 28,
  });

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  void _showViewer(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, _) => _PhotoViewerOverlay(
        photoUrl: photoUrl,
        initials: _initials,
        onEditPhoto: () async {
          Navigator.of(dialogContext).pop();
          await _pickAndUpload(context);
        },
      ),
      transitionBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  Future<void> _pickAndUpload(BuildContext context) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;

      final ext = picked.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png'].contains(ext)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solo se permiten imágenes JPG, JPEG o PNG'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        context.read<AuthBloc>().add(
          UploadProfilePhotoEvent(filePath: picked.path),
        );
      }
    } catch (e) {
      AppLogger.error('Error picking profile photo', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showViewer(context),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
        backgroundImage:
            photoUrl != null && photoUrl!.isNotEmpty
                ? NetworkImage(photoUrl!)
                : null,
        child: photoUrl == null || photoUrl!.isEmpty
            ? Text(
                _initials,
                style: TextStyle(
                  fontSize: radius * 0.58,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              )
            : null,
      ),
    );
  }
}

class _PhotoViewerOverlay extends StatelessWidget {
  final String? photoUrl;
  final String initials;
  final VoidCallback onEditPhoto;

  const _PhotoViewerOverlay({
    required this.photoUrl,
    required this.initials,
    required this.onEditPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Blurred + dark backdrop
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(color: Colors.black.withValues(alpha: 0.72)),
            ),
          ),
          // Content
          Center(
            child: GestureDetector(
              onTap: () {},
              behavior: HitTestBehavior.opaque,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  // Enlarged photo
                  CircleAvatar(
                    radius: 120,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    backgroundImage:
                        photoUrl != null && photoUrl!.isNotEmpty
                            ? NetworkImage(photoUrl!)
                            : null,
                    child: photoUrl == null || photoUrl!.isEmpty
                        ? Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  // Edit pencil button
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: onEditPhoto,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.white,
                        ),
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
