import 'dart:convert';
import 'package:flutter_app/core/utils/logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../utils/constants.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _secureStorage = const FlutterSecureStorage();

  User? _currentUser;
  User? get currentUser => _currentUser;

  // Login con email y contraseña
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final url = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.loginEndpoint}',
      );

      // Backend solo necesita email y password
      final Map<String, dynamic> loginData = {
        'email': email,
        'password': password,
      };

      AppLogger.debug('Intentando login a: $url');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(loginData),
      );

      AppLogger.debug('Status Code: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        // Guardar tokens
        final accessToken = data['accessToken']?.toString();
        if (accessToken != null && accessToken.isNotEmpty) {
          await _secureStorage.write(key: StorageKeys.accessToken, value: accessToken);
        }
        final refreshToken = data['refreshToken']?.toString();
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await _secureStorage.write(key: StorageKeys.refreshToken, value: refreshToken);
        }

        // Guardar rol desde la respuesta del backend
        final role = data['user']['role']?.toString() ?? 'CLIENT';
        await _secureStorage.write(key: StorageKeys.userRole, value: role);

        // Guardar usuario
        _currentUser = User.fromJson(data['user']);

        return {'success': true, 'user': _currentUser};
      } else {
        final error = jsonDecode(response.body);
        String errorMessage = 'Error al iniciar sesión';

        if (error['message'] != null) {
          if (error['message'] is List) {
            errorMessage = (error['message'] as List).join('\n');
          } else {
            errorMessage = error['message'].toString();
          }
        }

        AppLogger.error('Error del backend: $errorMessage');
        return {'success': false, 'error': errorMessage};
      }
    } catch (e) {
      AppLogger.error('Error en login: $e');
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  // Registro
  Future<Map<String, dynamic>> signup(Map<String, String> data) async {
    try {
      final url = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.signupEndpoint}',
      );

      AppLogger.debug('Intentando registro a: ');
      AppLogger.debug('Body enviado: ');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        // Guardar tokens
        final accessToken = responseData['accessToken']?.toString();
        if (accessToken != null && accessToken.isNotEmpty) {
          await _secureStorage.write(key: StorageKeys.accessToken, value: accessToken);
        }
        final refreshToken = responseData['refreshToken']?.toString();
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await _secureStorage.write(key: StorageKeys.refreshToken, value: refreshToken);
        }
        // Guardar rol del usuario desde la respuesta del backend
        final role = responseData['user']['role']?.toString() ?? 'CLIENT';
        await _secureStorage.write(key: StorageKeys.userRole, value: role);

        // Guardar usuario
        _currentUser = User.fromJson(responseData['user']);

        return {'success': true, 'user': _currentUser};
      } else {
        final error = jsonDecode(response.body);
        String errorMessage = 'Error al registrarse';

        if (error['message'] != null) {
          if (error['message'] is List) {
            errorMessage = (error['message'] as List).join('\n');
          } else {
            errorMessage = error['message'].toString();
          }
        }

        AppLogger.error('Error del backend: ');
        return {'success': false, 'error': errorMessage};
      }
    } catch (e) {
      AppLogger.error('Error en registro: ');
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  // Logout
  Future<void> logout() async {
    await _secureStorage.delete(key: StorageKeys.accessToken);
    await _secureStorage.delete(key: StorageKeys.refreshToken);
    await _secureStorage.delete(key: StorageKeys.userRole);
    _currentUser = null;
  }

  // Verificar si está autenticado
  // NOTE (legacy debt): this only checks token presence, not server-side expiry.
  // Expired tokens will still return true. Token expiry validation is handled
  // by the Dio interceptor in injection_container.dart via the refresh flow.
  Future<bool> isAuthenticated() async {
    final token = await _secureStorage.read(key: StorageKeys.accessToken);
    return token != null && token.isNotEmpty;
  }

  // Obtener usuario actual
  Future<User?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;

    try {
      final token = await _secureStorage.read(key: StorageKeys.accessToken);

      if (token == null) return null;

      final url = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.meEndpoint}',
      );
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = User.fromJson(data);
        return _currentUser;
      }
    } catch (e) {
      AppLogger.error('Error obteniendo usuario: ');
    }
    return null;
  }
}
