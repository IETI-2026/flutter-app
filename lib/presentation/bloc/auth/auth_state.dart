import 'package:equatable/equatable.dart';
import 'package:flutter_app/domain/entities/user.dart';

/// Auth States
/// Estados de autenticación
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial State
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Loading State
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Authenticated State
class Authenticated extends AuthState {
  final User user;

  const Authenticated({required this.user});

  @override
  List<Object?> get props => [user];
}

/// Unauthenticated State
class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// Auth Error State
class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Sign Up Success State
class SignUpSuccess extends AuthState {
  final User user;

  const SignUpSuccess({required this.user});

  @override
  List<Object?> get props => [user];
}
