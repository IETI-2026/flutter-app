import 'package:equatable/equatable.dart';

/// Base Failure Class
/// Todas las fallas heredan de esta clase
abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

/// Server Failure
/// Cuando hay un error en el servidor (5xx)
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// Network Failure
/// Cuando no hay conexión a internet
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Auth Failure
/// Cuando hay un error de autenticación (401, 403)
class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

/// Validation Failure
/// Cuando hay un error de validación (400)
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Not Found Failure
/// Cuando no se encuentra el recurso (404)
class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

/// Conflict Failure
/// Cuando hay un conflicto (409)
class ConflictFailure extends Failure {
  const ConflictFailure(super.message);
}

/// Cache Failure
/// Cuando hay un error al acceder al cache local
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}
