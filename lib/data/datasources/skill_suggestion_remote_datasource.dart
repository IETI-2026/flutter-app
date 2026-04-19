abstract class SkillSuggestionRemoteDataSource {
  Future<void> suggestSkill({
    required String name,
    required String description,
  });
}
