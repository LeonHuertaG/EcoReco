
class UsuarioModel {
  final String pkUsuario;
  final int fkRol;
  final String usuario;
  final String nombre;
  final String correo;
  final int estado;
  final String? token;

  UsuarioModel({
    required this.pkUsuario,
    required this.fkRol,
    required this.usuario,
    required this.nombre,
    required this.correo,
    required this.estado,
    this.token,
  });

  factory UsuarioModel.fromJson(
    Map<String, dynamic> json, {
    String? token,
  }) {
    return UsuarioModel(
      pkUsuario: '${json['pk_usuario'] ?? ''}',
      fkRol: int.tryParse(
        '${json['fk_rol'] ?? 0}',
      ) ?? 0,
      usuario: json['usuario']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      correo: json['correo']?.toString() ?? '',
      estado: int.tryParse(
        '${json['estado'] ?? 1}',
      ) ?? 1,
      token: token,
    );
  }

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
