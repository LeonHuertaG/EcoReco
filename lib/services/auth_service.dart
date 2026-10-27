import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/usuario_model.dart';

class LoginException implements Exception {
  const LoginException(this.message);

  final String message;
}

class AuthService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ecorecoloco-api.onrender.com/api',
  );

  static Future<UsuarioModel> login(String usuario, String password) async {
    try {
      final passBase64 = base64Encode(utf8.encode(password));

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'usuario': usuario, 'pass': password}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return UsuarioModel.fromJson(data['usuario'], token: data['token']);
      }
      if (response.statusCode == 401) {
        throw const LoginException('Usuario o contraseña incorrectos.');
      }
      if (response.statusCode >= 500) {
        throw const LoginException(
          'La API no pudo iniciar sesión. Revisa la terminal del backend y su conexión con MongoDB Atlas.',
        );
      }
      throw LoginException(
        'La API rechazó la solicitud (HTTP ${response.statusCode}).',
      );
    } on TimeoutException {
      throw const LoginException('La API tardó demasiado en responder.');
    } on http.ClientException {
      throw const LoginException(
        'No se pudo conectar con la API. Revisa el servidor y la conexión del teléfono.',
      );
    } on FormatException {
      throw const LoginException('La API devolvió una respuesta inválida.');
    }
  }
}
