import 'package:dio/dio.dart';
import 'package:flutter_app/core/error/exceptions.dart';
import 'package:flutter_app/core/utils/logger.dart';
import 'package:flutter_app/data/datasources/skill_suggestion_remote_datasource.dart';

class SkillSuggestionRemoteDataSourceImpl
    implements SkillSuggestionRemoteDataSource {
  final Dio dio;

  SkillSuggestionRemoteDataSourceImpl({required this.dio});

  @override
  Future<void> suggestSkill({
    required String name,
    required String description,
  }) async {
    try {
      AppLogger.info('Submitting skill suggestion: "$name"');

      final response = await dio.post(
        '/skill-suggestions',
        data: {'name': name, 'description': description},
      );

      if (response.statusCode != 200) {
        throw ServerException(
          'Unexpected response: ${response.statusCode}',
        );
      }

      AppLogger.info('Skill suggestion submitted successfully');
    } on DioException catch (e) {
      AppLogger.error('Skill suggestion request failed', e);

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw const NetworkException('Sin conexión a internet');
      }

      final message = _extractErrorMessage(e.response?.data);
      throw ServerException(message);
    } catch (e) {
      if (e is ServerException || e is NetworkException) rethrow;
      AppLogger.error('Unexpected skill suggestion error', e);
      throw ServerException(e.toString());
    }
  }

  String _extractErrorMessage(dynamic data) {
    if (data is Map) {
      final message = data['message'];
      if (message is List && message.isNotEmpty) {
        return message.map((e) => e.toString()).join('. ');
      }
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    return 'Error al enviar la sugerencia';
  }
}
