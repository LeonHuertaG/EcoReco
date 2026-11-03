import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../models/usuario_model.dart';
import '../screens/gestion_screen.dart';

class AuthController {
  bool isLoading = false;

  Future<void> ejecutarLogin({
    required BuildContext context,
    required String usuario,
    required String password,
    required Function(bool) onLoadingChanged,
  }) async {
    onLoadingChanged(true);

    // Llamada al servicio
    UsuarioModel? usuarioLogueado = await AuthService.login(usuario, password);

    onLoadingChanged(false);

    if (usuarioLogueado == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuario o contraseña incorrectos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!context.mounted) return;

    // Redirección interna por rol (fk_rol en la DB)
    switch (usuarioLogueado.fkRol) {
      case 1:
        // Admin
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bienvenido Admin: ${usuarioLogueado.nombre}'),
          ),
        );
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminHomeScreen()));
        break;
      case 2:
        // Vendedor -> Redirige a gestion_screen.dart
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GestionScreen()),
        );
        break;
      case 3:
        // Cobrador / Chofer
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bienvenido Chofer: ${usuarioLogueado.nombre}'),
          ),
        );
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChoferHomeScreen()));
        break;
      case 4:
        // Cliente
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bienvenido Cliente: ${usuarioLogueado.nombre}'),
          ),
        );
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ClienteHomeScreen()));
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rol de usuario sin pantalla asignada'),
            backgroundColor: Colors.orange,
          ),
        );
    }
  }
}
