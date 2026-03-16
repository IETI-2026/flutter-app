import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class LoginEvent extends AuthEvent {
  final String email;
  final String password;
  final String selectedRole;

  const LoginEvent({
    required this.email,
    required this.password,
    required this.selectedRole,
  });

  @override
  List<Object?> get props => [email, password, selectedRole];
}

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

class LoginWithGoogleEvent extends AuthEvent {
  final String selectedRole;

  const LoginWithGoogleEvent({required this.selectedRole});

  @override
  List<Object?> get props => [selectedRole];
}

class LogoutEvent extends AuthEvent {
  const LogoutEvent();
}

class CheckAuthStatusEvent extends AuthEvent {
  const CheckAuthStatusEvent();
}

class GetCurrentUserEvent extends AuthEvent {
  const GetCurrentUserEvent();
}
