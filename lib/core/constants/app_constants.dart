class AppConstants {
  static const String baseUrl = 'http://localhost:3000/api';
  static const String authEndpoint = '/auth';
  static const String usersEndpoint = '/users';

  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userRoleKey = 'user_role';
  static const String userDataKey = 'user_data';

  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const int defaultPageSize = 10;

  static const String roleClient = 'client';
  static const String roleProvider = 'provider';
  static const String roleAdmin = 'admin';
  static const String roleModerator = 'moderator';
}
