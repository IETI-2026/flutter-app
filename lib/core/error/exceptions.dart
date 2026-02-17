/// Base Exception Class
class ServerException implements Exception {
  final String message;
  const ServerException(this.message);
}

class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
}

class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);
}

class NotFoundException implements Exception {
  final String message;
  const NotFoundException(this.message);
}

class ConflictException implements Exception {
  final String message;
  const ConflictException(this.message);
}

class CacheException implements Exception {
  final String message;
  const CacheException(this.message);
}
