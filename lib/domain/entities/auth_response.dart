import 'package:equatable/equatable.dart';
import 'package:flutter_app/domain/entities/user.dart';

/// Auth Response Entity
/// Entidad que representa la respuesta de autenticación
class AuthResponse extends Equatable {
  final String accessToken;
  final String refreshToken;
  final User user;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  @override
  List<Object?> get props => [accessToken, refreshToken, user];
}
