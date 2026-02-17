import 'package:flutter/material.dart';

// API Configuration
class ApiConstants {
  // Para emulador Android usa 10.0.2.2
  // Para dispositivo físico usa la IP de tu máquina (ej: 192.168.1.x)
  static const String baseUrl = 'http://10.0.2.2:3000/api';
  static const String loginEndpoint = '/auth/login';
  static const String signupEndpoint = '/auth/signup';
  static const String refreshEndpoint = '/auth/refresh';
  static const String googleAuthEndpoint = '/auth/google';
  static const String meEndpoint = '/auth/me';
}

// Storage Keys
class StorageKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userRole = 'user_role';
}

// App Colors
class AppColors {
  static const Color primary = Color(0xFF4A80F5);
  static const Color secondary = Color(0xFFFFB800);
  static const Color background = Color(0xFFF5F7FA);
  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);
  static const Color error = Color(0xFFF44336);
  static const Color success = Color(0xFF4CAF50);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFFB2BEC3);
  static const Color greyLight = Color(0xFFDFE6E9);
}

// User Roles
class UserRoles {
  static const String client = 'CLIENT';
  static const String provider = 'PROVIDER';
  static const String admin = 'ADMIN';
}
