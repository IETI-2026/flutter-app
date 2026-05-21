import 'package:flutter_app/domain/entities/auth_response.dart';
import 'package:flutter_app/domain/entities/user.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponse> login({required String email, required String password});

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  });

  Future<AuthResponse> loginWithGoogle();

  Future<AuthResponse> refreshToken(String refreshToken);

  Future<User> getCurrentUser();

  Future<void> logout();

  Future<User> uploadProfilePhoto(String filePath);
}
