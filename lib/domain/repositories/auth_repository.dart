import 'package:dartz/dartz.dart';
import 'package:flutter_app/core/error/failures.dart';
import 'package:flutter_app/domain/entities/auth_response.dart';
import 'package:flutter_app/domain/entities/user.dart';

/// Auth Repository Interface
/// Contrato para operaciones de autenticación
abstract class AuthRepository {
  /// Login with email and password
  Future<Either<Failure, AuthResponse>> login({
    required String email,
    required String password,
  });

  /// Sign up with email and password
  Future<Either<Failure, AuthResponse>> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? phoneNumber,
  });

  /// Login with Google
  Future<Either<Failure, AuthResponse>> loginWithGoogle();

  /// Refresh access token
  Future<Either<Failure, AuthResponse>> refreshToken(String refreshToken);

  /// Get current user
  Future<Either<Failure, User>> getCurrentUser();

  /// Logout
  Future<Either<Failure, void>> logout();

  /// Check if user is logged in
  Future<bool> isLoggedIn();

  /// Get stored access token
  Future<String?> getAccessToken();

  /// Get stored refresh token
  Future<String?> getRefreshToken();

  /// Get stored user role
  Future<String?> getUserRole();
}
