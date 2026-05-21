import 'package:dartz/dartz.dart';
import 'package:flutter_app/core/error/failures.dart';
import 'package:flutter_app/domain/repositories/skill_suggestion_repository.dart';

class SuggestSkillUseCase {
  final SkillSuggestionRepository repository;

  SuggestSkillUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String name,
    required String description,
  }) async {
    return await repository.suggestSkill(name: name, description: description);
  }
}
