import 'package:flutter_app/data/models/user_model.dart';
import 'package:flutter_app/domain/entities/auth_response.dart';

/// Auth Response Model
/// Modelo de datos para la respuesta de autenticación
class AuthResponseModel extends AuthResponse {
  const AuthResponseModel({
    required super.accessToken,
    required super.refreshToken,
    required super.user,
  });

  /// From JSON
  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      accessToken: json['accessToken'] ?? json['access_token'] ?? '',
      refreshToken: json['refreshToken'] ?? json['refresh_token'] ?? '',
      user: UserModel.fromJson(json['user'] ?? {}),
    );
  }

  /// To JSON
  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'user': (user as UserModel).toJson(),
    };
  }

  /// To Entity
  AuthResponse toEntity() {
    return AuthResponse(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: user,
    );
  }
}
