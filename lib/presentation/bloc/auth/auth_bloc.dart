import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_app/core/utils/logger.dart';
import 'package:flutter_app/domain/usecases/get_current_user_usecase.dart';
import 'package:flutter_app/domain/usecases/login_usecase.dart';
import 'package:flutter_app/domain/usecases/login_with_google_usecase.dart';
import 'package:flutter_app/domain/usecases/logout_usecase.dart';
import 'package:flutter_app/domain/usecases/signup_usecase.dart';
import 'package:flutter_app/domain/usecases/upload_profile_photo_usecase.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_event.dart';
import 'package:flutter_app/presentation/bloc/auth/auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;
  final SignUpUseCase signUpUseCase;
  final LoginWithGoogleUseCase loginWithGoogleUseCase;
  final LogoutUseCase logoutUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final UploadProfilePhotoUseCase uploadProfilePhotoUseCase;

  AuthBloc({
    required this.loginUseCase,
    required this.signUpUseCase,
    required this.loginWithGoogleUseCase,
    required this.logoutUseCase,
    required this.getCurrentUserUseCase,
    required this.uploadProfilePhotoUseCase,
  }) : super(const AuthInitial()) {
    on<LoginEvent>(_onLogin);
    on<SignUpEvent>(_onSignUp);
    on<LoginWithGoogleEvent>(_onLoginWithGoogle);
    on<LogoutEvent>(_onLogout);
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<GetCurrentUserEvent>(_onGetCurrentUser);
    on<UploadProfilePhotoEvent>(_onUploadProfilePhoto);
  }

  Future<void> _onLogin(LoginEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());

    AppLogger.info('Processing login for: ${event.email}');

    final result = await loginUseCase(
      email: event.email,
      password: event.password,
    );

    result.fold(
      (failure) {
        AppLogger.error('Login failed: ${failure.message}');
        emit(AuthError(message: failure.message));
      },
      (authResponse) {
        AppLogger.event('login_success', {'method': 'email'});
        emit(Authenticated(user: authResponse.user, selectedRole: event.selectedRole));
      },
    );
  }

  Future<void> _onSignUp(SignUpEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());

    AppLogger.info('Processing sign up for: ${event.email}');

    final result = await signUpUseCase(
      email: event.email,
      password: event.password,
      fullName: event.fullName,
      role: event.role,
      phoneNumber: event.phoneNumber,
    );

    result.fold(
      (failure) {
        AppLogger.error('Sign up failed: ${failure.message}');
        emit(AuthError(message: failure.message));
      },
      (authResponse) {
        AppLogger.event('signup_success', {'role': event.role});
        emit(SignUpSuccess(user: authResponse.user));
      },
    );
  }

  Future<void> _onLoginWithGoogle(
    LoginWithGoogleEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    AppLogger.info('Processing Google login');

    final result = await loginWithGoogleUseCase();

    result.fold(
      (failure) {
        AppLogger.error('Google login failed: ${failure.message}');
        emit(AuthError(message: failure.message));
      },
      (authResponse) {
        AppLogger.event('login_success', {'method': 'google'});
        emit(Authenticated(user: authResponse.user, selectedRole: event.selectedRole));
      },
    );
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());

    AppLogger.info('Processing logout');

    await logoutUseCase();

    AppLogger.event('logout_success');
    emit(const Unauthenticated());
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    AppLogger.info('Checking auth status');

    final result = await getCurrentUserUseCase();

    result.fold(
      (failure) {
        AppLogger.info('User not authenticated');
        emit(const Unauthenticated());
      },
      (user) {
        AppLogger.info('User authenticated: ${user.email}');
        emit(Authenticated(user: user, selectedRole: user.role.toLowerCase()));
      },
    );
  }

  Future<void> _onGetCurrentUser(
    GetCurrentUserEvent event,
    Emitter<AuthState> emit,
  ) async {
    final result = await getCurrentUserUseCase();

    result.fold(
      (failure) {
        AppLogger.error('Get current user failed: ${failure.message}');
        emit(AuthError(message: failure.message));
      },
      (user) {
        AppLogger.info('Current user retrieved');
        emit(Authenticated(user: user, selectedRole: user.role.toLowerCase()));
      },
    );
  }

  Future<void> _onUploadProfilePhoto(
    UploadProfilePhotoEvent event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    emit(const AuthLoading());

    AppLogger.info('Uploading profile photo');

    final result = await uploadProfilePhotoUseCase(event.filePath);

    result.fold(
      (failure) {
        AppLogger.error('Upload profile photo failed: ${failure.message}');
        if (currentState is Authenticated) {
          emit(currentState);
        }
        emit(AuthError(message: failure.message));
      },
      (user) {
        AppLogger.event('profile_photo_uploaded');
        final selectedRole = currentState is Authenticated
            ? currentState.selectedRole
            : user.role.toLowerCase();
        emit(Authenticated(user: user, selectedRole: selectedRole));
      },
    );
  }
}
