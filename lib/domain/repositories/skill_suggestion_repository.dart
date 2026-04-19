import 'package:dartz/dartz.dart';
import 'package:flutter_app/core/error/failures.dart';

abstract class SkillSuggestionRepository {
  Future<Either<Failure, void>> suggestSkill({
    required String name,
    required String description,
  });
}
