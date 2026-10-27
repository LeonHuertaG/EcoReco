import 'package:flutter/material.dart';

import '../models/usuario_model.dart';
import '../screens/chofer/chofer_home.dart';
import '../screens/operacion/cliente_home.dart';
import '../screens/operacion/operacion_home.dart';
import '../services/auth_service.dart';
import '../services/chofer_api.dart';

class AuthController {
  Future<void> ejecutarLogin({
    required BuildContext context,
    required String usuario,
    required String password,
    required Function(bool) onLoadingChanged,
  }) async {
    onLoadingChanged(true);

    final UsuarioModel account;
    try {
      account = await AuthService.login(usuario, password);
    } on LoginException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
      return;
    } finally {
      if (context.mounted) onLoadingChanged(false);
    }

    if (!context.mounted) return;
    final token = account.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La API no devolvió una sesión válida.')),
      );
      return;
    }
    final Widget? screen = switch (account.fkRol) {
      1 || 2 => OperacionHome(
        nombre: account.nombre,
        token: token,
        admin: account.fkRol == 1,
      ),
      3 => ChoferHome(nombre: account.nombre, api: ChoferApi(token)),
      4 => ClienteHome(
        nombre: account.nombre,
        api: ChoferApi(token, scope: 'operacion'),
      ),
      _ => null,
    };
    if (screen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rol de usuario sin pantalla asignada.')),
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}
