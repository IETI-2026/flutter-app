import 'package:equatable/equatable.dart';

/// Auth Events
/// Eventos de autenticación
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Login Event
class LoginEvent extends AuthEvent {
  final String email;
  final String password;

  const LoginEvent({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

/// Sign Up Event
class SignUpEvent extends AuthEvent {
  final String email;
  final String password;
  final String fullName;
  final String role;
  final String? phoneNumber;

  const SignUpEvent({
    required this.email,
    required this.password,
    required this.fullName,
    required this.role,
    this.phoneNumber,
  });

  @override
  List<Object?> get props => [email, password, fullName, role, phoneNumber];
}

/// Login With Google Event
class LoginWithGoogleEvent extends AuthEvent {
  const LoginWithGoogleEvent();
}

/// Logout Event
class LogoutEvent extends AuthEvent {
  const LogoutEvent();
}

/// Check Auth Status Event
class CheckAuthStatusEvent extends AuthEvent {
  const CheckAuthStatusEvent();
}

/// Get Current User Event
class GetCurrentUserEvent extends AuthEvent {
  const GetCurrentUserEvent();
}
