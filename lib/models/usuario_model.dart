class UsuarioModel {
  final int pkUsuario;
  final int fkRol;
  final String usuario;
  final String nombre;
  final String correo;
  final int estado;

  UsuarioModel({
    required this.pkUsuario,
    required this.fkRol,
    required this.usuario,
    required this.nombre,
    required this.correo,
    required this.estado,
  });

  // Convertir JSON del servidor a Objeto Dart
  factory UsuarioModel.fromJson(Map<String, dynamic> json) {
    return UsuarioModel(
      pkUsuario: json['pk_usuario'] ?? 0,
      fkRol: json['fk_rol'] ?? 0,
      usuario: json['usuario'] ?? '',
      nombre: json['nombre'] ?? '',
      correo: json['correo'] ?? '',
      estado: json['estado'] ?? 1,
    );
  }

  // Convertir Objeto Dart a JSON
  Map<String, dynamic> toJson() {
    return {
      'pk_usuario': pkUsuario,
      'fk_rol': fkRol,
      'usuario': usuario,
      'nombre': nombre,
      'correo': correo,
      'estado': estado,
    };
  }
}
