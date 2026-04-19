import 'package:equatable/equatable.dart';

abstract class SkillSuggestionEvent extends Equatable {
  const SkillSuggestionEvent();

  @override
  List<Object?> get props => [];
}

class SubmitSkillSuggestionEvent extends SkillSuggestionEvent {
  final String name;
  final String description;

  const SubmitSkillSuggestionEvent({
    required this.name,
    required this.description,
  });

  @override
  List<Object?> get props => [name, description];
}
