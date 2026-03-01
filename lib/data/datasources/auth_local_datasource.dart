import 'package:flutter_app/domain/entities/user.dart';

abstract class AuthLocalDataSource {
  Future<void> saveAccessToken(String token);

  Future<String?> getAccessToken();

  Future<void> saveRefreshToken(String token);

  Future<String?> getRefreshToken();

  Future<void> saveUserRole(String role);

  Future<String?> getUserRole();

  Future<void> saveUserData(User user);

  Future<User?> getUserData();

  Future<void> clearAll();
}
