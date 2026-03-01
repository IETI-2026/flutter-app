import 'package:dartz/dartz.dart';
import 'package:flutter_app/core/error/failures.dart';
import 'package:flutter_app/domain/entities/auth_response.dart';
import 'package:flutter_app/domain/entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, AuthResponse>> login({
    required String email,
    required String password,
  });

  Future<Either<Failure, AuthResponse>> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? phoneNumber,
  });

  Future<Either<Failure, AuthResponse>> loginWithGoogle();

  Future<Either<Failure, AuthResponse>> refreshToken(String refreshToken);

  Future<Either<Failure, User>> getCurrentUser();

  Future<Either<Failure, void>> logout();

  Future<bool> isLoggedIn();

  Future<String?> getAccessToken();

  Future<String?> getRefreshToken();

  Future<String?> getUserRole();
}
