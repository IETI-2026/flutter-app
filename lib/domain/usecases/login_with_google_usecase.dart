import 'package:dartz/dartz.dart';
import 'package:flutter_app/core/error/failures.dart';
import 'package:flutter_app/domain/entities/auth_response.dart';
import 'package:flutter_app/domain/repositories/auth_repository.dart';

/// Login With Google Use Case
/// Caso de uso para iniciar sesión con Google
class LoginWithGoogleUseCase {
  final AuthRepository repository;

  LoginWithGoogleUseCase(this.repository);

  Future<Either<Failure, AuthResponse>> call() async {
    return await repository.loginWithGoogle();
  }
}
