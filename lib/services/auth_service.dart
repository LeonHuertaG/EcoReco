import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/usuario_model.dart';

class AuthService {
  // NOTA PARA EMULADOR Y DISPOSITIVOS:
  // - Si usas Emulador Android de Android Studio: 'http://10.0.2.2:3000/api'
  // - Si usas Windows Desktop / Web / Chrome: 'http://localhost:3000/api'
  // - Si usas un celular físico en tu red WiFi: 'http://TU_IP_LOCAL:3000/api'
  static const String baseUrl = 'http://192.168.1.10:3000/api';

  static Future<UsuarioModel?> login(String usuario, String password) async {
    try {
      String passBase64 = base64Encode(utf8.encode(password));

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'usuario': usuario, 'pass': passBase64}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UsuarioModel.fromJson(data['usuario']);
      } else {
        print('Error login: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error en AuthService al conectar con la API: $e');
      return null;
    }
  }
}
