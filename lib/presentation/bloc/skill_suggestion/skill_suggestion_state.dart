import 'package:equatable/equatable.dart';

abstract class SkillSuggestionState extends Equatable {
  const SkillSuggestionState();

  @override
  List<Object?> get props => [];
}

class SkillSuggestionInitial extends SkillSuggestionState {
  const SkillSuggestionInitial();
}

class SkillSuggestionLoading extends SkillSuggestionState {
  const SkillSuggestionLoading();
}

class SkillSuggestionSuccess extends SkillSuggestionState {
  const SkillSuggestionSuccess();
}

class SkillSuggestionFailure extends SkillSuggestionState {
  final String message;

  const SkillSuggestionFailure(this.message);

  @override
  List<Object?> get props => [message];
}
