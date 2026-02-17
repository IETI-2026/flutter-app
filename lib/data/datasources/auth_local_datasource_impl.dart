import 'dart:convert';
import 'package:flutter_app/core/constants/app_constants.dart';
import 'package:flutter_app/core/error/exceptions.dart';
import 'package:flutter_app/core/utils/logger.dart';
import 'package:flutter_app/data/datasources/auth_local_datasource.dart';
import 'package:flutter_app/data/models/user_model.dart';
import 'package:flutter_app/domain/entities/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auth Local Data Source Implementation
/// Implementación de operaciones locales de autenticación
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SharedPreferences sharedPreferences;

  AuthLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<void> saveAccessToken(String token) async {
    try {
      await sharedPreferences.setString(AppConstants.accessTokenKey, token);
      AppLogger.info('Access token saved');
    } catch (e) {
      AppLogger.error('Error saving access token', e);
      throw CacheException('Error al guardar token de acceso');
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      return sharedPreferences.getString(AppConstants.accessTokenKey);
    } catch (e) {
      AppLogger.error('Error getting access token', e);
      return null;
    }
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    try {
      await sharedPreferences.setString(AppConstants.refreshTokenKey, token);
      AppLogger.info('Refresh token saved');
    } catch (e) {
      AppLogger.error('Error saving refresh token', e);
      throw CacheException('Error al guardar refresh token');
    }
  }

  @override
  Future<String?> getRefreshToken() async {
    try {
      return sharedPreferences.getString(AppConstants.refreshTokenKey);
    } catch (e) {
      AppLogger.error('Error getting refresh token', e);
      return null;
    }
  }

  @override
  Future<void> saveUserRole(String role) async {
    try {
      await sharedPreferences.setString(AppConstants.userRoleKey, role);
      AppLogger.info('User role saved: $role');
    } catch (e) {
      AppLogger.error('Error saving user role', e);
      throw CacheException('Error al guardar rol de usuario');
    }
  }

  @override
  Future<String?> getUserRole() async {
    try {
      return sharedPreferences.getString(AppConstants.userRoleKey);
    } catch (e) {
      AppLogger.error('Error getting user role', e);
      return null;
    }
  }

  @override
  Future<void> saveUserData(User user) async {
    try {
      final userModel = UserModel(
        id: user.id,
        email: user.email,
        fullName: user.fullName,
        phoneNumber: user.phoneNumber,
        documentId: user.documentId,
        profilePhotoUrl: user.profilePhotoUrl,
        role: user.role,
        status: user.status,
        emailVerified: user.emailVerified,
        phoneVerified: user.phoneVerified,
        createdAt: user.createdAt,
        lastLoginAt: user.lastLoginAt,
      );

      final userJson = jsonEncode(userModel.toJson());
      await sharedPreferences.setString(AppConstants.userDataKey, userJson);
      AppLogger.info('User data saved');
    } catch (e) {
      AppLogger.error('Error saving user data', e);
      throw CacheException('Error al guardar datos de usuario');
    }
  }

  @override
  Future<User?> getUserData() async {
    try {
      final userJson = sharedPreferences.getString(AppConstants.userDataKey);
      if (userJson == null) return null;

      final userMap = jsonDecode(userJson) as Map<String, dynamic>;
      return UserModel.fromJson(userMap);
    } catch (e) {
      AppLogger.error('Error getting user data', e);
      return null;
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      await sharedPreferences.remove(AppConstants.accessTokenKey);
      await sharedPreferences.remove(AppConstants.refreshTokenKey);
      await sharedPreferences.remove(AppConstants.userRoleKey);
      await sharedPreferences.remove(AppConstants.userDataKey);
      AppLogger.info('All auth data cleared');
    } catch (e) {
      AppLogger.error('Error clearing auth data', e);
      throw CacheException('Error al limpiar datos de autenticación');
    }
  }
}
