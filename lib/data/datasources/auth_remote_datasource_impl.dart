import 'package:dio/dio.dart';
import 'package:flutter_app/core/constants/app_constants.dart';
import 'package:flutter_app/core/error/exceptions.dart';
import 'package:flutter_app/core/utils/logger.dart';
import 'package:flutter_app/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_app/data/models/auth_response_model.dart';
import 'package:flutter_app/data/models/user_model.dart';
import 'package:flutter_app/domain/entities/auth_response.dart';
import 'package:flutter_app/domain/entities/user.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Auth Remote Data Source Implementation
/// Implementación de operaciones remotas de autenticación
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;
  final GoogleSignIn googleSignIn;

  AuthRemoteDataSourceImpl({required this.dio, required this.googleSignIn});

  @override
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      AppLogger.info('Login attempt for email: $email');

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
        final message = e.response!.data['message'] ?? 'Error desconocido';

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
    required String role,
    String? phoneNumber,
  }) async {
    try {
      AppLogger.info('Sign up attempt for email: $email');

      final response = await dio.post(
        '${AppConstants.authEndpoint}/signup',
        data: {
          'email': email,
          'password': password,
          'fullName': fullName,
          'role': role,
          if (phoneNumber != null) 'phoneNumber': phoneNumber,
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
        final message = e.response!.data['message'] ?? 'Error desconocido';

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

      // First, get Google auth URL from backend
      final urlResponse = await dio.get('${AppConstants.authEndpoint}/google');

      if (urlResponse.statusCode != 200) {
        throw ServerException('Failed to get Google auth URL');
      }

      // Sign in with Google
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw AuthException('Google sign in cancelled');
      }

      // Get auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Send to backend
      final response = await dio.get(
        '${AppConstants.authEndpoint}/google/callback',
        queryParameters: {'code': googleAuth.idToken},
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        AppLogger.info('Google login successful');
        return AuthResponseModel.fromJson(response.data);
      } else {
        throw ServerException('Google login failed: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      AppLogger.error('Google login error', e);

      if (e.response != null) {
        final message =
            e.response!.data['message'] ?? 'Error en login con Google';
        throw AuthException(message);
      } else {
        throw NetworkException('Sin conexión a internet');
      }
    } catch (e) {
      AppLogger.error('Unexpected Google login error', e);
      if (e is AuthException) rethrow;
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
        final message =
            e.response!.data['message'] ?? 'Error al refrescar token';

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
        final message =
            e.response!.data['message'] ?? 'Error al obtener usuario';

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

      // Also sign out from Google if signed in
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }

      AppLogger.info('Logout successful');
    } on DioException catch (e) {
      AppLogger.error('Logout error', e);
      // Don't throw error on logout, just log it
    } catch (e) {
      AppLogger.error('Unexpected logout error', e);
      // Don't throw error on logout, just log it
    }
  }
}
