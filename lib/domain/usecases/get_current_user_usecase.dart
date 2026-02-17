import 'package:dartz/dartz.dart';
import 'package:flutter_app/core/error/failures.dart';
import 'package:flutter_app/domain/entities/user.dart';
import 'package:flutter_app/domain/repositories/auth_repository.dart';

/// Get Current User Use Case
/// Caso de uso para obtener el usuario actual
class GetCurrentUserUseCase {
  final AuthRepository repository;

  GetCurrentUserUseCase(this.repository);

  Future<Either<Failure, User>> call() async {
    return await repository.getCurrentUser();
  }
}
