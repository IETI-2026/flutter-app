import 'dart:convert';
import 'package:flutter_app/core/constants/app_constants.dart';
import 'package:flutter_app/core/error/exceptions.dart';
import 'package:flutter_app/core/utils/logger.dart';
import 'package:flutter_app/data/datasources/auth_local_datasource.dart';
import 'package:flutter_app/data/models/user_model.dart';
import 'package:flutter_app/domain/entities/user.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SharedPreferences sharedPreferences;
  final FlutterSecureStorage _secureStorage;

  AuthLocalDataSourceImpl({
    required this.sharedPreferences,
    required FlutterSecureStorage secureStorage,
  }) : _secureStorage = secureStorage;

  @override
  Future<void> saveAccessToken(String token) async {
    try {
      await _secureStorage.write(key: AppConstants.accessTokenKey, value: token);
      AppLogger.info('Access token saved');
    } catch (e) {
      AppLogger.error('Error saving access token', e);
      throw CacheException('Error al guardar token de acceso');
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: AppConstants.accessTokenKey);
    } catch (e) {
      AppLogger.error('Error getting access token', e);
      return null;
    }
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    try {
      await _secureStorage.write(key: AppConstants.refreshTokenKey, value: token);
      AppLogger.info('Refresh token saved');
    } catch (e) {
      AppLogger.error('Error saving refresh token', e);
      throw CacheException('Error al guardar refresh token');
    }
  }

  @override
  Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: AppConstants.refreshTokenKey);
    } catch (e) {
      AppLogger.error('Error getting refresh token', e);
      return null;
    }
  }

  @override
  Future<void> saveUserRole(String role) async {
    try {
      await _secureStorage.write(key: AppConstants.userRoleKey, value: role);
      AppLogger.info('User role saved');
    } catch (e) {
      AppLogger.error('Error saving user role', e);
      throw CacheException('Error al guardar rol de usuario');
    }
  }

  @override
  Future<String?> getUserRole() async {
    try {
      return await _secureStorage.read(key: AppConstants.userRoleKey);
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
    final errors = <Object>[];

    for (final key in [
      AppConstants.accessTokenKey,
      AppConstants.refreshTokenKey,
      AppConstants.userRoleKey,
    ]) {
      try {
        await _secureStorage.delete(key: key);
      } catch (e) {
        AppLogger.error('Error deleting key $key from secure storage', e);
        errors.add(e);
      }
    }

    try {
      await sharedPreferences.remove(AppConstants.userDataKey);
    } catch (e) {
      AppLogger.error('Error removing user data from shared preferences', e);
      errors.add(e);
    }

    if (errors.isEmpty) {
      AppLogger.info('All auth data cleared');
    } else {
      throw CacheException('Error al limpiar datos de autenticación');
    }
  }
}
