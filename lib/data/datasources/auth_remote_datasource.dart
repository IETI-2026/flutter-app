import 'package:flutter_app/domain/entities/auth_response.dart';
import 'package:flutter_app/domain/entities/user.dart';

/// Auth Remote Data Source Interface
/// Contrato para operaciones remotas de autenticación
abstract class AuthRemoteDataSource {
  /// Login with email and password
  Future<AuthResponse> login({
    required String email,
    required String password,
  });

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? phoneNumber,
  });

  /// Login with Google
  Future<AuthResponse> loginWithGoogle();

  /// Refresh access token
  Future<AuthResponse> refreshToken(String refreshToken);

  /// Get current user
  Future<User> getCurrentUser();

  /// Logout
  Future<void> logout();
}
