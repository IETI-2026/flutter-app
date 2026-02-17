import 'package:flutter_app/domain/entities/user.dart';

/// Auth Local Data Source Interface
/// Contrato para operaciones locales de autenticación
abstract class AuthLocalDataSource {
  /// Save access token
  Future<void> saveAccessToken(String token);

  /// Get access token
  Future<String?> getAccessToken();

  /// Save refresh token
  Future<void> saveRefreshToken(String token);

  /// Get refresh token
  Future<String?> getRefreshToken();

  /// Save user role
  Future<void> saveUserRole(String role);

  /// Get user role
  Future<String?> getUserRole();

  /// Save user data
  Future<void> saveUserData(User user);

  /// Get user data
  Future<User?> getUserData();

  /// Clear all stored data
  Future<void> clearAll();
}
