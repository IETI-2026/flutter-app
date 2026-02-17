import 'package:dartz/dartz.dart';
import 'package:flutter_app/core/error/failures.dart';
import 'package:flutter_app/domain/entities/auth_response.dart';
import 'package:flutter_app/domain/repositories/auth_repository.dart';

/// Sign Up Use Case
/// Caso de uso para registrarse con email y contraseña
class SignUpUseCase {
  final AuthRepository repository;

  SignUpUseCase(this.repository);

  Future<Either<Failure, AuthResponse>> call({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? phoneNumber,
  }) async {
    return await repository.signUp(
      email: email,
      password: password,
      fullName: fullName,
      role: role,
      phoneNumber: phoneNumber,
    );
  }
}
