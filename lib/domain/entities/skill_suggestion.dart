import 'package:equatable/equatable.dart';

class SkillSuggestion extends Equatable {
  final String name;
  final String description;

  const SkillSuggestion({required this.name, required this.description});

  @override
  List<Object?> get props => [name, description];
}
