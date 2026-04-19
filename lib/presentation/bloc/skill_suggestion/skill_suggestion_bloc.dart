import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_app/core/utils/logger.dart';
import 'package:flutter_app/domain/usecases/suggest_skill_usecase.dart';
import 'package:flutter_app/presentation/bloc/skill_suggestion/skill_suggestion_event.dart';
import 'package:flutter_app/presentation/bloc/skill_suggestion/skill_suggestion_state.dart';

class SkillSuggestionBloc
    extends Bloc<SkillSuggestionEvent, SkillSuggestionState> {
  final SuggestSkillUseCase suggestSkillUseCase;

  SkillSuggestionBloc({required this.suggestSkillUseCase})
      : super(const SkillSuggestionInitial()) {
    on<SubmitSkillSuggestionEvent>(_onSubmit);
  }

  Future<void> _onSubmit(
    SubmitSkillSuggestionEvent event,
    Emitter<SkillSuggestionState> emit,
  ) async {
    emit(const SkillSuggestionLoading());

    AppLogger.info('Submitting skill suggestion: "${event.name}"');

    final result = await suggestSkillUseCase(
      name: event.name,
      description: event.description,
    );

    result.fold(
      (failure) {
        AppLogger.error('Skill suggestion failed: ${failure.message}');
        emit(SkillSuggestionFailure(failure.message));
      },
      (_) {
        AppLogger.event('skill_suggestion_submitted', {'name': event.name});
        emit(const SkillSuggestionSuccess());
      },
    );
  }
}
