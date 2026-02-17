import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../utils/constants.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

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

      print('🔵 Intentando login a: $url');
      print('📧 Email: $email');
      print('📦 Body enviado: $loginData');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(loginData),
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        // Guardar tokens
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(StorageKeys.accessToken, data['accessToken']);
        if (data['refreshToken'] != null) {
          await prefs.setString(StorageKeys.refreshToken, data['refreshToken']);
        }

        // Guardar rol desde la respuesta del backend
        await prefs.setString(
          StorageKeys.userRole,
          data['user']['role'] ?? 'CLIENT',
        );

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

        print('❌ Error del backend: $errorMessage');
        return {'success': false, 'error': errorMessage};
      }
    } catch (e) {
      print('❌ Error en login: $e');
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  // Registro
  Future<Map<String, dynamic>> signup(Map<String, String> data) async {
    try {
      final url = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.signupEndpoint}',
      );

      print('🔵 Intentando registro a: $url');
      print('� Body enviado: $data');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        // Guardar tokens
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          StorageKeys.accessToken,
          responseData['accessToken'],
        );
        if (responseData['refreshToken'] != null) {
          await prefs.setString(
            StorageKeys.refreshToken,
            responseData['refreshToken'],
          );
        }
        // Guardar rol del usuario desde la respuesta del backend
        await prefs.setString(
          StorageKeys.userRole,
          responseData['user']['role'] ?? 'CLIENT',
        );

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

        print('❌ Error del backend: $errorMessage');
        return {'success': false, 'error': errorMessage};
      }
    } catch (e) {
      print('❌ Error en registro: $e');
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.accessToken);
    await prefs.remove(StorageKeys.refreshToken);
    await prefs.remove(StorageKeys.userRole);
    _currentUser = null;
  }

  // Verificar si está autenticado
  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(StorageKeys.accessToken);
    return token != null && token.isNotEmpty;
  }

  // Obtener usuario actual
  Future<User?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(StorageKeys.accessToken);

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
      print('❌ Error obteniendo usuario: $e');
    }
    return null;
  }
}
