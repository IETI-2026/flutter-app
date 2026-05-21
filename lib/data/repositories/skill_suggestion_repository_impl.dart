import 'package:dartz/dartz.dart';
import 'package:flutter_app/core/error/exceptions.dart';
import 'package:flutter_app/core/error/failures.dart';
import 'package:flutter_app/data/datasources/skill_suggestion_remote_datasource.dart';
import 'package:flutter_app/domain/repositories/skill_suggestion_repository.dart';

class SkillSuggestionRepositoryImpl implements SkillSuggestionRepository {
  final SkillSuggestionRemoteDataSource remoteDataSource;

  SkillSuggestionRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, void>> suggestSkill({
    required String name,
    required String description,
  }) async {
    try {
      await remoteDataSource.suggestSkill(name: name, description: description);
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
