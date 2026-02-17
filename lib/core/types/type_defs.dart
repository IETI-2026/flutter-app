import 'package:dartz/dartz.dart';

/// Type Definitions
/// Definiciones de tipos comunes usados en toda la app

/// Either<Failure, Success>
/// Representa el resultado de una operación que puede fallar
typedef ResultType<T> = Either<dynamic, T>;
