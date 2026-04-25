import 'package:dio/dio.dart';
import 'package:flutter_app/core/constants/app_constants.dart';
import 'package:flutter_app/core/services/app_insights_service.dart';
import 'package:flutter_app/core/services/tenant_service.dart';
import 'package:flutter_app/core/services/theme_service.dart';
import 'package:flutter_app/core/services/websocket_service.dart';
import 'package:flutter_app/core/utils/logger.dart';
import 'package:flutter_app/data/datasources/auth_local_datasource.dart';
import 'package:flutter_app/data/datasources/auth_local_datasource_impl.dart';
import 'package:flutter_app/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_app/data/datasources/auth_remote_datasource_impl.dart';
import 'package:flutter_app/data/datasources/address_remote_datasource.dart';
import 'package:flutter_app/data/datasources/geocoding_remote_datasource.dart';
import 'package:flutter_app/data/datasources/skill_suggestion_remote_datasource.dart';
import 'package:flutter_app/data/datasources/skill_suggestion_remote_datasource_impl.dart';
import 'package:flutter_app/data/repositories/address_repository_impl.dart';
import 'package:flutter_app/data/repositories/auth_repository_impl.dart';
import 'package:flutter_app/data/repositories/skill_suggestion_repository_impl.dart';
import 'package:flutter_app/domain/repositories/address_repository.dart';
import 'package:flutter_app/domain/repositories/auth_repository.dart';
import 'package:flutter_app/domain/repositories/skill_suggestion_repository.dart';
import 'package:flutter_app/domain/usecases/create_address_usecase.dart';
import 'package:flutter_app/domain/usecases/delete_address_usecase.dart';
import 'package:flutter_app/domain/usecases/get_addresses_usecase.dart';
import 'package:flutter_app/domain/usecases/get_current_user_usecase.dart';
import 'package:flutter_app/domain/usecases/login_usecase.dart';
import 'package:flutter_app/domain/usecases/login_with_google_usecase.dart';
import 'package:flutter_app/domain/usecases/logout_usecase.dart';
import 'package:flutter_app/domain/usecases/set_default_address_usecase.dart';
import 'package:flutter_app/domain/usecases/signup_usecase.dart';
import 'package:flutter_app/domain/usecases/suggest_skill_usecase.dart';
import 'package:flutter_app/domain/usecases/upload_profile_photo_usecase.dart';
import 'package:flutter_app/presentation/bloc/address/address_bloc.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_bloc.dart';
import 'package:flutter_app/presentation/bloc/location/location_cubit.dart';
import 'package:flutter_app/presentation/bloc/skill_suggestion/skill_suggestion_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sl = GetIt.instance;

String _buildAuthorizationHeader(String token) {
  final normalized = token.trim();
  if (normalized.toLowerCase().startsWith('bearer ')) {
    return normalized;
  }
  return 'Bearer $normalized';
}

void _setAuthorizationHeader(Map<String, dynamic> headers, String token) {
  headers.remove('Authorization');
  headers.remove('authorization');
  headers['Authorization'] = _buildAuthorizationHeader(token);
}

String? _firstNonEmptyString(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
  }
  return null;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  return null;
}

String? _extractAccessTokenFromRefreshPayload(Map<String, dynamic> payload) {
  final data = _asMap(payload['data']);
  final tokens = _asMap(payload['tokens']);
  final dataTokens = _asMap(data?['tokens']);

  return _firstNonEmptyString([
    payload['accessToken'],
    payload['access_token'],
    data?['accessToken'],
    data?['access_token'],
    tokens?['accessToken'],
    tokens?['access_token'],
    dataTokens?['accessToken'],
    dataTokens?['access_token'],
  ]);
}

String? _extractRefreshTokenFromRefreshPayload(Map<String, dynamic> payload) {
  final data = _asMap(payload['data']);
  final tokens = _asMap(payload['tokens']);
  final dataTokens = _asMap(data?['tokens']);

  return _firstNonEmptyString([
    payload['refreshToken'],
    payload['refresh_token'],
    data?['refreshToken'],
    data?['refresh_token'],
    tokens?['refreshToken'],
    tokens?['refresh_token'],
    dataTokens?['refreshToken'],
    dataTokens?['refresh_token'],
  ]);
}

void _trackHttpRequest(RequestOptions options, int statusCode, bool success) {
  final startMs = options.extra['_requestStart'] as int?;
  final duration = startMs != null
      ? Duration(milliseconds: DateTime.now().millisecondsSinceEpoch - startMs)
      : Duration.zero;
  AppInsightsService.instance.trackRequest(
    '${options.method} ${options.path}',
    options.uri.toString(),
    statusCode,
    duration,
    success,
  );
}

Future<void> initializeDependencies() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);
  sl.registerLazySingleton<FlutterSecureStorage>(() => const FlutterSecureStorage());

  sl.registerLazySingleton<TenantService>(() => TenantService());
  sl.registerLazySingleton<ThemeService>(() => ThemeService(sharedPreferences));
  sl.registerLazySingleton<WebSocketService>(() => WebSocketService());

  sl.registerLazySingleton<Dio>(() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectionTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await sl<AuthLocalDataSource>().getAccessToken();
            if (token != null && token.isNotEmpty) {
              _setAuthorizationHeader(options.headers, token);
              AppLogger.debug(
                'Auth interceptor: token attached to ${options.path}',
              );
            } else {
              AppLogger.warning(
                'Auth interceptor: no token found for ${options.path}',
              );
            }
          } catch (e) {
            AppLogger.error('Auth interceptor: failed to get token', e);
          }
          // Add tenant header to non-auth requests
          final isAuthRequest = options.path.contains('/auth/');
          if (!isAuthRequest) {
            options.headers['X-Tenant-ID'] = sl<TenantService>().tenantId;
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          final statusCode = error.response?.statusCode;
          final requestOptions = error.requestOptions;
          final isAuthRequest = requestOptions.path.contains('/auth/');
          final alreadyRetried =
              requestOptions.extra['retryAfterRefresh'] == true;

          if (statusCode == 401 && !isAuthRequest && !alreadyRetried) {
            try {
              final refreshToken = await sl<AuthLocalDataSource>()
                  .getRefreshToken();

              if (refreshToken == null || refreshToken.isEmpty) {
                AppLogger.warning(
                  'Refresh skipped: no refresh token available',
                );
                return handler.next(error);
              }

              final refreshDio = Dio(
                BaseOptions(
                  baseUrl: AppConstants.baseUrl,
                  connectTimeout: AppConstants.connectionTimeout,
                  receiveTimeout: AppConstants.receiveTimeout,
                  headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                  },
                ),
              );

              final refreshResponse = await refreshDio.post(
                '${AppConstants.authEndpoint}/refresh',
                data: {'refreshToken': refreshToken},
              );

              if (refreshResponse.data is! Map<String, dynamic>) {
                AppLogger.warning('Refresh failed: invalid refresh payload');
                return handler.next(error);
              }

              final refreshData = refreshResponse.data as Map<String, dynamic>;
              final newAccessToken = _extractAccessTokenFromRefreshPayload(
                refreshData,
              );
              final newRefreshToken = _extractRefreshTokenFromRefreshPayload(
                refreshData,
              );

              if (newAccessToken == null || newAccessToken.isEmpty) {
                AppLogger.warning('Refresh failed: access token is empty');
                return handler.next(error);
              }

              await sl<AuthLocalDataSource>().saveAccessToken(newAccessToken);
              if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
                await sl<AuthLocalDataSource>().saveRefreshToken(
                  newRefreshToken,
                );
              }

              final retryHeaders = Map<String, dynamic>.from(
                requestOptions.headers,
              );
              _setAuthorizationHeader(retryHeaders, newAccessToken);
              retryHeaders['X-Tenant-ID'] = sl<TenantService>().tenantId;

              final retryOptions = requestOptions.copyWith(
                headers: retryHeaders,
                extra: {...requestOptions.extra, 'retryAfterRefresh': true},
              );

              final retryResponse = await dio.fetch(retryOptions);
              AppLogger.info(
                'Request recovered after token refresh: ${requestOptions.path}',
              );
              return handler.resolve(retryResponse);
            } catch (e) {
              AppLogger.warning(
                'Refresh flow failed for ${requestOptions.path}',
                e,
              );
            }
          }

          return handler.next(error);
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.extra['_requestStart'] = DateTime.now().millisecondsSinceEpoch;
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _trackHttpRequest(response.requestOptions, response.statusCode ?? 200, true);
          return handler.next(response);
        },
        onError: (error, handler) {
          _trackHttpRequest(error.requestOptions, error.response?.statusCode ?? 0, false);
          return handler.next(error);
        },
      ),
    );

    return dio;
  });

  sl.registerLazySingleton<GoogleSignIn>(
    () => GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId: AppConstants.googleServerClientId.isEmpty
          ? null
          : AppConstants.googleServerClientId,
    ),
  );

  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sharedPreferences: sl(), secureStorage: sl()),
  );

  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(dio: sl(), googleSignIn: sl()),
  );

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl(), localDataSource: sl()),
  );

  sl.registerLazySingleton<GeocodingRemoteDataSource>(
    () => GeocodingRemoteDataSource(dio: sl()),
  );

  sl.registerLazySingleton<SkillSuggestionRemoteDataSource>(
    () => SkillSuggestionRemoteDataSourceImpl(dio: sl()),
  );

  sl.registerLazySingleton<SkillSuggestionRepository>(
    () => SkillSuggestionRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton<AddressRemoteDataSource>(
    () => AddressRemoteDataSource(dio: sl()),
  );

  sl.registerLazySingleton<AddressRepository>(
    () => AddressRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton(() => GetAddressesUseCase(sl()));
  sl.registerLazySingleton(() => CreateAddressUseCase(sl()));
  sl.registerLazySingleton(() => SetDefaultAddressUseCase(sl()));
  sl.registerLazySingleton(() => DeleteAddressUseCase(sl()));

  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => SignUpUseCase(sl()));
  sl.registerLazySingleton(() => LoginWithGoogleUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => UploadProfilePhotoUseCase(sl()));
  sl.registerLazySingleton(() => SuggestSkillUseCase(sl()));

  sl.registerLazySingleton(
    () => LocationCubit(geocodingDataSource: sl(), tenantService: sl(), dio: sl()),
  );

  sl.registerFactory(
    () => AuthBloc(
      loginUseCase: sl(),
      signUpUseCase: sl(),
      loginWithGoogleUseCase: sl(),
      logoutUseCase: sl(),
      getCurrentUserUseCase: sl(),
      uploadProfilePhotoUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => SkillSuggestionBloc(suggestSkillUseCase: sl()),
  );

  sl.registerFactory(
    () => AddressBloc(
      getAddresses: sl(),
      createAddress: sl(),
      setDefault: sl(),
      deleteAddress: sl(),
    ),
  );
}
