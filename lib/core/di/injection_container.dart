import 'package:dio/dio.dart';
import 'package:flutter_app/core/constants/app_constants.dart';
import 'package:flutter_app/data/datasources/auth_local_datasource.dart';
import 'package:flutter_app/data/datasources/auth_local_datasource_impl.dart';
import 'package:flutter_app/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_app/data/datasources/auth_remote_datasource_impl.dart';
import 'package:flutter_app/data/repositories/auth_repository_impl.dart';
import 'package:flutter_app/domain/repositories/auth_repository.dart';
import 'package:flutter_app/domain/usecases/get_current_user_usecase.dart';
import 'package:flutter_app/domain/usecases/login_usecase.dart';
import 'package:flutter_app/domain/usecases/login_with_google_usecase.dart';
import 'package:flutter_app/domain/usecases/logout_usecase.dart';
import 'package:flutter_app/domain/usecases/signup_usecase.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sl = GetIt.instance;

/// Dependency Injection Setup
/// Configuración de inyección de dependencias con get_it
Future<void> initializeDependencies() async {
  // External Dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

  // Dio Client
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

    // Add interceptor for authentication
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await sl<AuthLocalDataSource>().getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );

    return dio;
  });

  // Google Sign In
  sl.registerLazySingleton<GoogleSignIn>(() => GoogleSignIn(
    scopes: ['email', 'profile'],
  ));

  // Data Sources
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sharedPreferences: sl()),
  );

  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(dio: sl(), googleSignIn: sl()),
  );

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => SignUpUseCase(sl()));
  sl.registerLazySingleton(() => LoginWithGoogleUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));

  // BLoCs
  sl.registerFactory(
    () => AuthBloc(
      loginUseCase: sl(),
      signUpUseCase: sl(),
      loginWithGoogleUseCase: sl(),
      logoutUseCase: sl(),
      getCurrentUserUseCase: sl(),
    ),
  );
}
