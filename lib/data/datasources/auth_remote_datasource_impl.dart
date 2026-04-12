import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/core/constants/app_constants.dart';
import 'package:flutter_app/core/error/exceptions.dart';
import 'package:flutter_app/core/utils/logger.dart';
import 'package:flutter_app/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_app/data/models/auth_response_model.dart';
import 'package:flutter_app/data/models/user_model.dart';
import 'package:flutter_app/domain/entities/auth_response.dart';
import 'package:flutter_app/domain/entities/user.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;
  final GoogleSignIn googleSignIn;

  AuthRemoteDataSourceImpl({required this.dio, required this.googleSignIn});

  String _extractErrorMessage(dynamic data, String fallback) {
    if (data == null) return fallback;

    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final message = map['message'];
      if (message is List && message.isNotEmpty) {
        return message.map((e) => e.toString()).join('. ');
      }
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }

      final errors = map['errors'];
      if (errors is Map) {
        final parts = <String>[];
        for (final entry in errors.entries) {
          final v = entry.value;
          if (v is List) {
            parts.addAll(v.map((e) => e.toString()));
          } else if (v != null) {
            parts.add(v.toString());
          }
        }
        if (parts.isNotEmpty) {
          return parts.join('. ');
        }
      }
    }

    return fallback;
  }

  bool _isConnectivityError(DioException exception) {
    return exception.type == DioExceptionType.connectionTimeout ||
        exception.type == DioExceptionType.sendTimeout ||
        exception.type == DioExceptionType.receiveTimeout ||
        exception.type == DioExceptionType.connectionError;
  }

  AuthException _mapGooglePlatformException(PlatformException exception) {
    final message = exception.message ?? '';
    final details = exception.details?.toString() ?? '';
    final merged = '$message $details';

    if (merged.contains('ApiException: 10')) {
      return const AuthException(
        'Google Sign-In no está configurado correctamente para Android (ApiException 10). Verifica packageName, SHA-1/SHA-256 y Web Client ID.',
      );
    }

    if (exception.code == 'sign_in_canceled') {
      return const AuthException('Inicio de sesión con Google cancelado');
    }

    return AuthException(
      'Error de Google Sign-In: ${exception.message ?? exception.code}',
    );
  }

  @override
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final domain = email.contains('@') ? email.split('@').last : 'unknown';
      AppLogger.info('Login attempt for domain: $domain');

      final response = await dio.post(
        '${AppConstants.authEndpoint}/login',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        AppLogger.info('Login successful');
        return AuthResponseModel.fromJson(response.data);
      } else {
        throw ServerException('Login failed: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      AppLogger.error('Login error', e);

      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final message = _extractErrorMessage(
          e.response!.data,
          'Error desconocido',
        );

        switch (statusCode) {
          case 401:
            throw AuthException(message);
          case 400:
            throw ValidationException(message);
          case 500:
            throw ServerException(message);
          default:
            throw ServerException(message);
        }
      } else {
        throw NetworkException('Sin conexión a internet');
      }
    } catch (e) {
      AppLogger.error('Unexpected login error', e);
      throw ServerException(e.toString());
    }
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    try {
      final domain = email.contains('@') ? email.split('@').last : 'unknown';
      AppLogger.info('Sign up attempt for domain: $domain');

      // El DTO de Nest no admite `role`; el perfil cliente/profesional se define en la app.
      final response = await dio.post(
        '${AppConstants.authEndpoint}/signup',
        data: {
          'email': email,
          'password': password,
          'fullName': fullName,
          if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
            'phoneNumber': phoneNumber.trim(),
        },
      );

      if (response.statusCode == 201) {
        AppLogger.info('Sign up successful');
        return AuthResponseModel.fromJson(response.data);
      } else {
        throw ServerException('Sign up failed: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      AppLogger.error('Sign up error', e);

      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final message = _extractErrorMessage(
          e.response!.data,
          'Error desconocido',
        );

        switch (statusCode) {
          case 409:
            throw ConflictException(message);
          case 400:
            throw ValidationException(message);
          case 500:
            throw ServerException(message);
          default:
            throw ServerException(message);
        }
      } else {
        throw NetworkException('Sin conexión a internet');
      }
    } catch (e) {
      AppLogger.error('Unexpected sign up error', e);
      throw ServerException(e.toString());
    }
  }

  @override
  Future<AuthResponse> loginWithGoogle() async {
    try {
      AppLogger.info('Google login attempt');

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw AuthException('Inicio de sesión con Google cancelado');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final idToken = googleAuth.idToken?.trim();

      if (idToken == null || idToken.isEmpty) {
        throw AuthException(
          'Google no devolvió un ID token válido. Revisa client IDs y SHA-1/SHA-256.',
        );
      }

      final response = await dio.post(
        '${AppConstants.authEndpoint}/google/mobile',
        data: {'idToken': idToken},
        options: Options(
          sendTimeout: AppConstants.connectionTimeout,
          receiveTimeout: AppConstants.receiveTimeout,
        ),
      );

      if (response.statusCode == 200) {
        AppLogger.info('Google login successful');
        return AuthResponseModel.fromJson(response.data);
      } else {
        throw ServerException('Google login failed: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      AppLogger.error('Google login error', e);

      if (e.response != null) {
        final message = _extractErrorMessage(
          e.response?.data,
          'Error en inicio de sesión con Google',
        );
        throw AuthException(message);
      }

      if (_isConnectivityError(e)) {
        throw NetworkException('Sin conexión a internet');
      }

      throw ServerException('No se pudo completar el login con Google');
    } on PlatformException catch (e) {
      AppLogger.error('Google platform error', e);
      throw _mapGooglePlatformException(e);
    } catch (e) {
      AppLogger.error('Unexpected Google login error', e);
      if (e is AuthException) rethrow;
      if (e is NetworkException) rethrow;
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<AuthResponse> refreshToken(String refreshToken) async {
    try {
      AppLogger.info('Refreshing token');

      final response = await dio.post(
        '${AppConstants.authEndpoint}/refresh',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        AppLogger.info('Token refreshed successfully');
        return AuthResponseModel.fromJson(response.data);
      } else {
        throw ServerException(
          'Token refresh failed: ${response.statusMessage}',
        );
      }
    } on DioException catch (e) {
      AppLogger.error('Token refresh error', e);

      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final message = _extractErrorMessage(
          e.response!.data,
          'Error al refrescar token',
        );

        if (statusCode == 401) {
          throw AuthException(message);
        } else {
          throw ServerException(message);
        }
      } else {
        throw NetworkException('Sin conexión a internet');
      }
    } catch (e) {
      AppLogger.error('Unexpected token refresh error', e);
      throw ServerException(e.toString());
    }
  }

  @override
  Future<User> getCurrentUser() async {
    try {
      AppLogger.info('Getting current user');

      final response = await dio.get('${AppConstants.authEndpoint}/me');

      if (response.statusCode == 200) {
        AppLogger.info('Current user retrieved');
        return UserModel.fromJson(response.data);
      } else {
        throw ServerException(
          'Get current user failed: ${response.statusMessage}',
        );
      }
    } on DioException catch (e) {
      AppLogger.error('Get current user error', e);

      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final message = _extractErrorMessage(
          e.response!.data,
          'Error al obtener usuario',
        );

        if (statusCode == 401) {
          throw AuthException(message);
        } else {
          throw ServerException(message);
        }
      } else {
        throw NetworkException('Sin conexión a internet');
      }
    } catch (e) {
      AppLogger.error('Unexpected get current user error', e);
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      AppLogger.info('Logging out');

      await dio.post('${AppConstants.authEndpoint}/logout');

      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }

      AppLogger.info('Logout successful');
    } on DioException catch (e) {
      AppLogger.error('Logout error', e);
    } catch (e) {
      AppLogger.error('Unexpected logout error', e);
    }
  }

  @override
  Future<User> uploadProfilePhoto(String filePath) async {
    try {
      AppLogger.info('Uploading profile photo');

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });

      final response = await dio.patch(
        '${AppConstants.usersEndpoint}/me/profile-photo',
        data: formData,
      );

      if (response.statusCode == 200) {
        AppLogger.info('Profile photo uploaded successfully');
        return UserModel.fromJson(response.data);
      } else {
        throw ServerException(
          'Upload failed: ${response.statusMessage}',
        );
      }
    } on DioException catch (e) {
      AppLogger.error('Upload profile photo error', e);

      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final message = _extractErrorMessage(
          e.response!.data,
          'Error al subir la imagen',
        );

        if (statusCode == 400) {
          throw ValidationException(message);
        } else if (statusCode == 401) {
          throw AuthException(message);
        } else {
          throw ServerException(message);
        }
      } else {
        throw NetworkException('Sin conexión a internet');
      }
    } catch (e) {
      AppLogger.error('Unexpected upload error', e);
      if (e is ValidationException) rethrow;
      if (e is AuthException) rethrow;
      if (e is NetworkException) rethrow;
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }
}
