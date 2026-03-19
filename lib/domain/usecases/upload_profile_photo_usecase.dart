import 'package:dartz/dartz.dart';
import 'package:flutter_app/core/error/failures.dart';
import 'package:flutter_app/domain/entities/user.dart';
import 'package:flutter_app/domain/repositories/auth_repository.dart';

class UploadProfilePhotoUseCase {
  final AuthRepository repository;

  UploadProfilePhotoUseCase(this.repository);

  Future<Either<Failure, User>> call(String filePath) {
    return repository.uploadProfilePhoto(filePath);
  }
}
